# frozen_string_literal: true

require 'nokogiri'
require_relative 'typography_profiles'
begin
  require 'rouge'
rescue LoadError => e
  # Rouge 未加载(通常是旧 server 进程未重启 Bundler 未识别新 gem)
  # 降级处理:代码块用普通样式显示,无高亮。打印警告便于排查。
  warn "[StyleRenderer] Rouge not available: #{e.message}. Code highlight disabled. Please restart your Rails server."
end

module Wechat
  # 微信公众号草稿专用的 HTML 渲染器
  #
  # 背景：微信草稿 API 只认内联 style="...",不支持 <style>/<link>/class 选择器、
  #       伪元素、动画等。premailer 通用 CSS 内联对复杂主题保真度低。
  #
  # 策略（参考 mdnice / doocs-md）：
  #   1. 主题提供 tag => inline_style 映射（wx_style_map, jsonb）
  #   2. Nokogiri 遍历 DOM,按标签名直接贴样式,特殊元素特殊处理
  #   3. 代码块用 Rouge 生成已内联样式的高亮 HTML
  #
  # 保真度高、零 CSS 解析、可精确控制。
  class StyleRenderer
    # 哪些 key 被视为"整体容器样式"(不是按 tag 贴)
    META_KEYS = %w[_root _code_theme _code_font _link_color].freeze

    # 默认兜底样式(主题没指定某个 tag 时使用)
    DEFAULT_FALLBACK = {
      'p'    => 'margin:12px 0;line-height:1.75;color:#333;font-size:15px;',
      'h1'   => 'font-size:22px;font-weight:bold;margin:24px 0 16px;color:#222;',
      'h2'   => 'font-size:19px;font-weight:bold;margin:20px 0 14px;color:#222;',
      'h3'   => 'font-size:17px;font-weight:bold;margin:18px 0 12px;color:#333;',
      'h4'   => 'font-size:16px;font-weight:bold;margin:16px 0 10px;color:#333;',
      'blockquote' => 'border-left:4px solid #ccc;padding:8px 16px;background:#f8f9fa;color:#555;margin:12px 0;',
      'strong' => 'font-weight:bold;color:inherit;',
      'em'   => 'font-style:italic;',
      'a'    => 'color:#3498db;text-decoration:underline;',
      'ul'   => 'padding-left:24px;margin:12px 0;',
      'ol'   => 'padding-left:24px;margin:12px 0;',
      'li'   => 'line-height:1.75;margin:6px 0;color:#333;',
      'hr'   => 'border:none;border-top:1px solid #eee;margin:24px 0;',
      'table' => 'width:100%;border-collapse:collapse;font-size:14px;margin:12px 0;',
      'th'   => 'background:#f6f8fa;border:1px solid #ddd;padding:6px 10px;text-align:left;font-weight:bold;',
      'td'   => 'border:1px solid #ddd;padding:6px 10px;',
      'img'  => 'max-width:100%;display:block;margin:12px auto;border-radius:4px;',
      'code_inline' => 'background:#f4f4f4;color:#c7254e;padding:2px 6px;border-radius:3px;font-size:90%;font-family:Consolas,Monaco,Menlo,monospace;',
      'code_block' => 'font-family:Consolas,Monaco,Menlo,monospace;font-size:13px;line-height:1.5;',
      'pre'  => 'background:#f6f8fa;padding:16px;border-radius:6px;overflow-x:auto;margin:16px 0;font-family:Consolas,Monaco,Menlo,monospace;'
    }.freeze

    def initialize(style_map, primary_color: nil, bold_color: nil, typography_profile: nil)
      @map = (style_map || {}).stringify_keys
      @code_theme = @map['_code_theme'] || 'github'
      @primary_color = normalize_color(primary_color) || @map['_default_primary'] || '#1e6bb8'
      @bold_color = normalize_color(bold_color) || @map['_default_bold'] || @primary_color
      @typography_profile = TypographyProfiles.fetch(typography_profile)
    end

    # 主入口:接收 Commonmarker 产出的 HTML 字符串,返回内联样式后的 HTML
    def render(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html, 'UTF-8')

      # 先处理代码块(Rouge 高亮,替换整块节点)
      highlight_code_blocks(doc)

      # 扁平化 loose list: <li><p>..</p></li> → <li>..</li>
      # 否则微信渲染器会给 <li> 和内部 <p> 各算一个块,
      # 出现 "1.(空) 2.内容 3.(空) 4.内容" 的双重编号 bug
      flatten_loose_list_items(doc)

      # 遍历 DOM,贴标签级样式
      doc.traverse do |node|
        next unless node.element?
        apply_tag_style(node)
      end

      inner = doc.to_html(encoding: 'UTF-8')

      # Nokogiri HTML 序列化会对块级标签自动 pretty-print 插换行,
      # 例如 "<ol>\n<li>\n<strong>..</strong></li>\n<li>..." ——
      # 微信编辑器会把这些换行当独立空块渲染,导致列表双重编号 bug。
      # 清洗所有 list 相关标签之间的空白
      inner = inner.gsub(/(<li[^>]*>)\s+/) { $1 }
                   .gsub(/\s+(<\/li>)/) { $1 }
                   .gsub(/(<(?:ol|ul)[^>]*>)\s+/) { $1 }
                   .gsub(/\s+(<\/(?:ol|ul)>)/) { $1 }
                   .gsub(/(<\/li>)\s+(<li[^>]*>)/) { "#{$1}#{$2}" }

      root_style = append_style(
        substitute(@map['_root'] || 'font-size:17px;color:#333;line-height:1.75;'),
        TypographyProfiles.inline_style(@typography_profile[:id], '_root')
      )
      %(<section class="wemd-article" style="#{root_style}">#{inner}</section>)
    end

    # 对已经被其他 CSS 内联器处理过的 HTML 只追加排版档位。
    # 用于没有 wx_style_map 的旧主题，仍保证最终发布字号遵守同一契约。
    def apply_typography(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html, 'UTF-8')

      doc.traverse do |node|
        apply_typography_style(node) if node.element?
      end

      root = doc.at_css('section.wemd-article')
      if root
        merge_style(
          root,
          TypographyProfiles.inline_style(@typography_profile[:id], '_root'),
          override: true
        )
        doc.to_html(encoding: 'UTF-8')
      else
        root_style = TypographyProfiles.inline_style(@typography_profile[:id], '_root')
        %(<section class="wemd-article" style="#{root_style}">#{doc.to_html(encoding: 'UTF-8')}</section>)
      end
    end

    def effective_typography
      TypographyProfiles.public_payload(@typography_profile[:id])
    end

    private

    # {{PRIMARY}} / {{BOLD}} 占位符替换为实际颜色
    def substitute(style_str)
      return style_str unless style_str.is_a?(String)
      style_str.gsub('{{PRIMARY}}', @primary_color).gsub('{{BOLD}}', @bold_color)
    end

    # 归一化颜色:接受 #RGB / #RRGGBB,其他情况返回 nil
    def normalize_color(c)
      return nil if c.blank?
      s = c.to_s.strip
      return s if s.match?(/\A#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/)
      nil
    end

    def style_for(key)
      substitute(@map[key] || DEFAULT_FALLBACK[key])
    end

    def apply_tag_style(node)
      tag = node.name.downcase

      case tag
      when 'pre'
        # pre 已由 highlight_code_blocks 处理过则跳过重复贴
        merge_style(node, style_for('pre')) unless node['data-wx-highlighted']
      when 'code'
        # 行内 code (非代码块内的)
        unless node.parent&.name == 'pre'
          merge_style(node, style_for('code_inline'))
        end
      when 'table'
        node['border'] = '1'
        node['cellspacing'] = '0'
        node['cellpadding'] = '6'
        merge_style(node, style_for('table'))
      when 'img'
        merge_style(node, style_for('img'))
      when 'a'
        # 微信草稿里外链不可点击,但保留样式
        merge_style(node, style_for('a'))
      else
        s = style_for(tag)
        merge_style(node, s) if s
      end

      apply_typography_style(node)
    end

    def merge_style(node, style_str, override: false)
      return if style_str.to_s.empty?
      existing = node['style'].to_s.strip.chomp(';')
      new_val = style_str.to_s.strip.chomp(';')
      existing = remove_overridden_properties(existing, new_val) if override
      styles = override ? [existing, new_val] : [new_val, existing]
      node['style'] = styles.reject(&:empty?).join(';')
    end

    def append_style(base_style, overriding_style)
      base = base_style.to_s.strip.chomp(';')
      override = overriding_style.to_s.strip.chomp(';')
      base = remove_overridden_properties(base, override)
      [base, override]
        .reject(&:empty?).join(';')
    end

    def remove_overridden_properties(existing_style, overriding_style)
      properties = overriding_style.scan(/(?:\A|;)\s*([\w-]+)\s*:/).flatten
      properties.reduce(existing_style.to_s) do |style, property|
        style
          .gsub(/(?:\A|;)\s*#{Regexp.escape(property)}\s*:[^;]*(?=;|\z)/i, '')
          .sub(/\A;+/, '')
          .gsub(/;{2,}/, ';')
      end
    end

    def apply_typography_style(node)
      key = typography_key_for(node)
      return unless key

      style = TypographyProfiles.inline_style(@typography_profile[:id], key)
      merge_style(node, style, override: true)
    end

    def typography_key_for(node)
      tag = node.name.downcase
      return 'footnote' if footnote_node?(node) && %w[p li div section].include?(tag)
      return 'blockquote' if tag == 'blockquote' || (tag == 'p' && node.ancestors('blockquote').any?)
      return node.parent&.name == 'pre' ? 'code_block' : 'code_inline' if tag == 'code'
      return tag if %w[p ul ol li h1 h2 h3 h4 h5 h6 table th td figcaption].include?(tag)

      nil
    end

    def footnote_node?(node)
      ([node] + node.ancestors).any? do |candidate|
        candidate['class'].to_s.split.any? { |name| name.start_with?('footnote') }
      end
    end

    # 代码高亮:Rouge + 内联样式
    # 原始结构: <pre><code class="language-ruby">...</code></pre>
    # 输出:    <pre style="...block..." data-wx-highlighted="1"><code>...带 span style 的高亮...</code></pre>
    def highlight_code_blocks(doc)
      return doc unless defined?(Rouge)
      formatter = Rouge::Formatters::HTMLInline.new(rouge_theme)

      doc.css('pre > code').each do |code_node|
        pre = code_node.parent
        lang = detect_lang(code_node)
        source = code_node.content

        begin
          lexer = lang ? Rouge::Lexer.find_fancy(lang, source) : nil
          lexer ||= Rouge::Lexers::PlainText.new
          highlighted = formatter.format(lexer.lex(source))
        rescue => e
          Rails.logger.warn "[WX_RENDER] rouge highlight failed: #{e.message}, fallback to plain"
          highlighted = CGI.escapeHTML(source)
        end

        # 构造新的 pre > code 节点
        new_code = Nokogiri::XML::Node.new('code', doc)
        new_code.inner_html = highlighted
        merge_style(new_code, style_for('code_block'))

        pre.inner_html = ''
        pre.add_child(new_code)
        # 先清除 Rouge formatter 可能在 pre 上设置的 background-color，
        # 再用 wx_style_map['pre'] 覆盖，避免 Rouge 主题背景色胜出。
        pre.remove_attribute('style')
        merge_style(pre, style_for('pre'))
        pre['data-wx-highlighted'] = '1'
      end
    end

    # 扁平化 loose list item: <li><p>foo</p></li> → <li>foo</li>
    # loose list 在微信里会被双重渲染(<li> 自己一个 marker + 内部 <p> 新块)
    # 导致 5 条变 10 条的双重编号 bug
    #
    # 同时清洗 ol/ul 内 <li> 之间的纯空白文本节点: Commonmarker 会在
    # </li> 与下一个 <li> 之间留换行符,微信把这些换行当独立空块渲染,
    # 仍会双重编号。所以把 ol/ul 直接子节点里的空白 text 节点删掉。
    def flatten_loose_list_items(doc)
      # 1) loose list 扁平化
      doc.css('li').each do |li|
        child_elements = li.children.select(&:element?)
        next if child_elements.empty?
        next unless child_elements.all? { |c| c.name == 'p' }

        # 多个 <p>: 用 <br><br> 连接(微信里 <li> 内不能有块级)
        new_html = child_elements.map(&:inner_html).join('<br/><br/>')
        li.inner_html = new_html
      end

      # 2) 清洗 ol/ul 里 <li> 之间的空白文本节点
      doc.css('ol, ul').each do |list|
        list.children.each do |child|
          child.remove if child.text? && child.content.strip.empty?
        end
      end

      # 3) 再清洗每个 <li> 内首尾的空白文本节点(防御性)
      doc.css('li').each do |li|
        while (first = li.children.first) && first.text? && first.content.strip.empty?
          first.remove
        end
        while (last = li.children.last) && last.text? && last.content.strip.empty?
          last.remove
        end
      end
    end

    def detect_lang(code_node)
      klass = code_node['class'].to_s
      # commonmarker 产出 class="language-ruby"
      if klass =~ /(?:language|lang)-([\w+-]+)/i
        return $1.downcase
      end
      nil
    end

    def rouge_theme
      @_rouge_theme ||= begin
        theme_class = Rouge::Theme.find(@code_theme) || Rouge::Themes::Github
        theme_class.new
      end
    end
  end
end
