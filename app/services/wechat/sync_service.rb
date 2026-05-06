require 'net/http'
require 'json'
require 'uri'
require 'down'
require 'net/http/post/multipart'

module Wechat
  class SyncService
    API_URL = "https://api.weixin.qq.com/cgi-bin"

    class SyncError < StandardError; end

    def initialize(user)
      @user = user
      @app_id = user.wechat_app_id
      @app_secret = user.wechat_app_secret
    end

    def ready?
      @app_id.present? && @app_secret.present?
    end

    # 获取 Access Token，自带简单的缓存机制（官方建议缓存，有效期 2 小时）
    def access_token
      cache_key = "wechat_access_token_#{@app_id}"
      token = Rails.cache.read(cache_key)
      return token if token.present?

      url = URI("#{API_URL}/token?grant_type=client_credential&appid=#{@app_id}&secret=#{@app_secret}")
      response = Net::HTTP.get_response(url)
      result = JSON.parse(response.body)

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      # 提前 5 分钟过期
      expires_in = result["expires_in"].to_i - 300
      Rails.cache.write(cache_key, result["access_token"], expires_in: expires_in)
      
      result["access_token"]
    end

    # 通过图文素材上传接口，将我们的网络图片转换为微信能用的 mmbiz URL
    # 这个接口不占用公众号每天的素材配额，专门用来传正文图片的。
    def upload_image_for_article(image_url)
      uri = URI("#{API_URL}/media/uploadimg?access_token=#{access_token}")
      
      # 使用 Down 下载图片到临时文件
      tempfile = Down.download(image_url)
      
      request = Net::HTTP::Post::Multipart.new(
        uri.path + "?#{uri.query}",
        { "media" => UploadIO.new(tempfile, tempfile.content_type, tempfile.original_filename) }
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(request)
      result = JSON.parse(response.body)

      tempfile.close
      tempfile.unlink

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      result["url"]
    rescue Down::Error => e
      raise SyncError, "图片下载失败: #{e.message} (#{image_url})"
    end

    # 上传永久素材图片作为封面（草稿一定要用 MediaID）
    def upload_material_image(image_url)
      uri = URI("#{API_URL}/material/add_material?access_token=#{access_token}&type=image")
      
      tempfile = Down.download(image_url)
      
      request = Net::HTTP::Post::Multipart.new(
        uri.path + "?#{uri.query}",
        { "media" => UploadIO.new(tempfile, tempfile.content_type, tempfile.original_filename) }
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(request)
      result = JSON.parse(response.body)

      tempfile.close
      tempfile.unlink

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      result["media_id"]
    rescue Down::Error => e
      raise SyncError, "封面图片下载失败: #{e.message} (#{image_url})"
    end

    # 同步整个文档到微信草稿箱
    def push_draft(document, thumb_media_id)
      # 第一阶段：将 Markdown 转换为 HTML
      html_content = markdown_to_html(document.content)

      # 第二阶段：解析 HTML 并替换所有 img -> mmbiz_url
      processed_content = process_html_images(html_content)

      # 第三阶段：把主题 CSS 内联到每个元素的 style 属性上
      # 微信公众号草稿不支持 <style>/<link>，只认内联 style
      processed_content = apply_theme_styles(processed_content, document.theme)

      # NOTE: 针对 45166 invalid content，微信极度严格，在 JSON 编码时不能有双引号错误转义或特殊 HTML 转义。
      # 而且内容外部经常需要一个基础标签，如果在生成 HTML 时失去了最外层的换行或者什么，也会被拦截。
      
      # 第三阶段：提交草稿
      uri = URI("#{API_URL}/draft/add?access_token=#{access_token}")
      
      payload = {
        articles: [
          {
            title: document.title,
            content: processed_content,
            thumb_media_id: thumb_media_id,
            author: @user.name,
            need_open_comment: 0,
            only_fans_can_comment: 0
          }
        ]
      }

      req = Net::HTTP::Post.new(uri)
      req.content_type = 'application/json; charset=utf-8'
      json_body = payload.to_json
      req.body = json_body

      # ===== 调试日志：打印真正发给微信的完整 Payload =====
      Rails.logger.warn("[WECHAT_DEBUG] Title: #{document.title.inspect}")
      Rails.logger.warn("[WECHAT_DEBUG] Author: #{@user.name.inspect}")
      Rails.logger.warn("[WECHAT_DEBUG] Thumb Media ID: #{thumb_media_id.inspect}")
      Rails.logger.warn("[WECHAT_DEBUG] Content Length: #{processed_content.bytesize} bytes")
      Rails.logger.warn("[WECHAT_DEBUG] Content (first 2000 chars): #{processed_content[0, 2000]}")
      Rails.logger.warn("[WECHAT_DEBUG] JSON Body (first 3000 chars): #{json_body[0, 3000]}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(req)
      result = JSON.parse(response.body)

      Rails.logger.warn("[WECHAT_DEBUG] Response: #{response.body}")

      if result["errcode"] && result["errcode"] != 0
        handle_error(result)
      end

      result["media_id"]
    end

    # 本地预览渲染:完整复用同步管道,但跳过微信图片上传(保留原图 URL)
    # 前端可以直接把返回的 HTML 塞到预览区,所见即 = 同步到草稿后的效果
    # (差别:图片 src 未变成 mmbiz_url,但视觉上没差别)
    def render_preview_html(document)
      html_content = markdown_to_html(document.content)
      html_content = clean_anchors_only(html_content)
      apply_theme_styles(html_content, document.theme)
    end

    private

    # Markdown -> HTML (Commonmarker,关闭自动锚点)
    def markdown_to_html(content)
      require 'commonmarker'
      # 去掉开头的一级标题（# xxx），因为它已经作为文章标题填入了公众号标题栏，正文不应重复出现
      stripped = content.to_s.sub(/\A\s*#[^#][^\n]*\n?/, '')
      Commonmarker.to_html(stripped, options: {
        render: { unsafe: true }, # 允许渲染行内 HTML 如 <img> <br>
        extension: {
          header_ids: nil  # 关闭 heading 自动锚点,微信草稿不允许 <a href="#..."> 链接
        }
      })
    end

    # 仅清洗锚点(预览用,不上传图片)
    def clean_anchors_only(html_content)
      doc = Nokogiri::HTML::DocumentFragment.parse(html_content)
      doc.css('a').each do |a|
        href = a['href'].to_s
        if href.start_with?('#') || a['class'].to_s.include?('anchor')
          a.replace(a.children)
        end
      end
      doc.to_html(encoding: 'UTF-8')
    end

    # 用 Nokogiri 解析 HTML，找到所有的 img 并走微信上传
    def process_html_images(html_content)
      doc = Nokogiri::HTML::DocumentFragment.parse(html_content)

      # 兜底清理：删除 heading 自动锚点产生的 <a class="anchor" href="#xxx">...</a>
      # 微信 45166 invalid content 的罪魁祸首之一
      doc.css('a').each do |a|
        href = a['href'].to_s
        if href.start_with?('#') || a['class'].to_s.include?('anchor')
          # 保留内部文本，移除标签本身
          a.replace(a.children)
        end
      end

      doc.css('img').each do |img|
        src = img['src']
        next if src.blank?
        # 如果已经是微信图片，跳过
        next if src.include?('mmbiz.qpic.cn') || src.include?('mmbiz.qlogo.cn')
        
        # 兼容相对路径（拼接主机名）
        full_url = format_image_url(src)
        
        begin
          wechat_url = upload_image_for_article(full_url)
          img['src'] = wechat_url
        rescue => e
          Rails.logger.error "Wechat Image Upload Failed: #{e.message}"
          # 图片上传失败时策略：保留原图，但是微信侧可能由于防盗链无法显示
        end
      end

      # Nokogiri 转换出来的 html 默认可能有一些不必要的格式，强制按 UTF-8 转出来
      doc.to_html(encoding: 'UTF-8')
    end

    # 将主题样式应用到 HTML
    # 优先级:
    #   1. theme.wx_style_map 存在 -> 用 Wechat::StyleRenderer (高保真,推荐)
    #   2. 否则 -> fallback 到 premailer 通用 CSS 内联(保真度一般)
    # 微信公众号草稿不支持 <style>/<link>/<class>,只认内联 style
    def apply_theme_styles(html_content, theme)
      return ensure_block_wrap(html_content) if theme.blank?

      # ===== 路径 1:wx_style_map (新方案,推荐) =====
      if theme.respond_to?(:wx_style_map) && theme.wx_style_map.present?
        begin
          require Rails.root.join('app/services/wechat/style_renderer')
          primary = @user&.wx_primary_color.presence
          bold    = @user&.wx_bold_color.presence
          renderer = Wechat::StyleRenderer.new(theme.wx_style_map, primary_color: primary, bold_color: bold)
          result = renderer.render(html_content)
          Rails.logger.info "[WECHAT] apply_theme_styles via StyleRenderer theme=#{theme.name} primary=#{primary || 'theme-default'} bold=#{bold || 'theme-default'}"
          return result
        rescue => e
          Rails.logger.error "[WECHAT] StyleRenderer failed: #{e.class}: #{e.message}, fallback to premailer"
        end
      end

      # ===== 路径 2:premailer 通用 CSS 内联(兜底) =====
      return ensure_block_wrap(html_content) if theme.css.blank?

      require 'premailer'

      # 用一个最小的 HTML 文档包裹，premailer 才能正确工作
      # 注意必须显式声明 UTF-8，否则 Nokogiri 会按 Latin-1 解析导致中文乱码
      full_html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
          <style type="text/css">#{theme.css}</style>
        </head>
        <body><section class="wemd-article">#{html_content}</section></body>
        </html>
      HTML

      premailer = Premailer.new(
        full_html,
        with_html_string: true,
        warn_level: Premailer::Warnings::SAFE,
        preserve_styles: false,
        remove_classes: false,
        remove_ids: true,
        remove_comments: true,
        input_encoding: 'UTF-8',
        adapter: :nokogiri
      )

      inlined = premailer.to_inline_css

      # premailer 会返回完整 HTML，抽出 body 里 section 的内容并保留 section 包装
      doc = Nokogiri::HTML::DocumentFragment.parse(inlined, 'UTF-8')
      section = doc.at_css('section.wemd-article')
      result = section ? section.to_html(encoding: 'UTF-8') : inlined

      # 兜底：微信要求最外层有块级元素
      result = "<section>#{result}</section>" unless result.match?(/\A\s*<(p|div|section|h\d|ul|ol|blockquote|pre|table|figure)/)
      result = "<p>空草稿</p>" if result.to_s.strip.empty?
      result
    rescue => e
      Rails.logger.error "[WECHAT] apply_theme_styles failed: #{e.message}, fallback to raw html"
      ensure_block_wrap(html_content)
    end

    # 不带主题时的最小包装
    def ensure_block_wrap(html_content)
      html_content = "<p>空草稿</p>" if html_content.to_s.strip.empty?
      unless html_content.match?(/\A\s*<(p|div|section|h\d|ul|ol|blockquote|pre|table|figure)/)
        html_content = "<p>#{html_content}</p>"
      end
      html_content
    end

    def format_image_url(url)
      return url if url.start_with?('http')
      
      # 如果是相对路径，需要拼上服务器前缀 （可以通过环境变量配置）
      base_url = ENV.fetch('HOST_URL', 'http://localhost:3000')
      URI.join(base_url, url).to_s
    end

    def handle_error(result)
      error_msg = case result["errcode"]
                  when 40001 then "AppSecret 错误或者 AccessToken 无效。"
                  when 40013 then "AppID 不合法。"
                  when 40164 then "IP 未在微信公众号后台白名单中！(极其重要)"
                  when 41004 then "AppSecret 缺少。"
                  when 41005 then "缺少多媒体文件数据。"
                  when 45009 then "接口调用超过公众号的每日限额。"
                  else "微信接口错误: #{result['errmsg']} (错误码: #{result['errcode']})"
                  end
      raise SyncError, error_msg
    end
  end
end