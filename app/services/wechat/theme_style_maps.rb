# frozen_string_literal: true

# 内置主题的 wx_style_map 配置(用于 Wechat::StyleRenderer)
#
# 约定:
#   - 每个 key 是 HTML 标签名(小写),值是内联 CSS 字符串
#   - {{PRIMARY}} 占位符会被 StyleRenderer 替换成用户选择的主色
#   - {{BOLD}} 占位符会被替换成用户选择的加粗色
#   - 特殊 key:
#       _root            最外层 section 样式
#       _code_theme      Rouge 高亮主题名
#       _default_primary 该主题在用户未选色时的默认主色
#       code_inline      行内 <code>
#       code_block       <pre> 内的 <code>

module Wechat
  module ThemeStyleMaps
    # 李笑来原版标志配色
    LXL_GREEN  = '#009688'   # 标志青绿(em / 标题 / 引用边框 / 表头)
    LXL_ORANGE = '#BF360C'   # 标志深橙红(strong 默认 / hr)

    # === 李笑来原版:Markdown Here Classic Style 高保真移植 ===
    # 关键特征:
    #   - 行高 1.8em,字间距 0.1em
    #   - 段落 text-align: justify(两端对齐)
    #   - 标题全部居中 + {{PRIMARY}}(默认青绿)
    #   - H1/H2 带底部细线
    #   - strong = {{BOLD}}(默认深橙红) / em = {{PRIMARY}}(默认青绿)
    #   - hr 分隔线 = {{BOLD}}
    #   - blockquote 左边 2px 主色线,灰色文字
    #   - ul 使用空心圆点(circle)
    #   - 表格 th = 主色底 + 白字
    DEFAULT = {
      '_root'            => "font-size:16px;color:#000;line-height:1.8;letter-spacing:0.1em;word-break:break-word;font-family:Optima-Regular,Optima,PingFangSC-light,PingFangTC-light,'PingFang SC','Microsoft YaHei','微软雅黑','Segoe UI',Roboto,Helvetica,Arial,sans-serif;",
      '_code_theme'      => 'github',
      '_default_primary' => LXL_GREEN,

      'p'      => 'font-size:16px;line-height:1.8;letter-spacing:0.1em;margin:1.5em 5px;color:#000;text-align:justify;',

      'h1'     => 'font-size:24px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;border-bottom:1px solid #ddd;',
      'h2'     => 'font-size:20px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;border-bottom:1px solid #eee;',
      'h3'     => 'font-size:18px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',
      'h4'     => 'font-size:16px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',
      'h5'     => 'font-size:16px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',
      'h6'     => 'font-size:16px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',

      'strong' => 'font-weight:bold;color:{{BOLD}};',
      'em'     => 'font-style:italic;color:{{PRIMARY}};',
      'del'    => 'font-style:italic;color:#000;text-decoration:line-through;',

      'a'      => 'color:{{PRIMARY}};text-decoration:none;font-weight:bold;border-bottom:1px solid {{PRIMARY}};',

      'blockquote' => 'display:block;border-left:2px solid {{PRIMARY}};background:transparent;color:#777;padding:0 10px;margin:10px 5px 10px 1em;font-size:16px;',

      'ul'     => 'padding-left:15px;margin:10px 5px;color:#000;list-style-type:circle;',
      'ol'     => 'padding-left:15px;margin:10px 5px;color:#000;list-style-type:decimal;',
      'li'     => 'line-height:1.8;letter-spacing:0.1em;margin:10px;color:#010101;',

      'hr'     => 'height:0;margin:1.5em auto;border:none;border-top:1px solid {{BOLD}};',

      'code_inline' => 'font-size:14px;padding:2px 4px;border-radius:2px;margin:0 2px;color:{{PRIMARY}};background-color:rgba(27,31,35,0.05);font-family:Roboto,"Courier New",Consolas,Inconsolata,Courier,monospace;word-break:break-all;',

      # 代码块:浅灰背景 + 深色文字,清晰可读
      'pre'        => 'margin:1em 5px;padding:0;background:#f8f8f8;border:1px solid #e0e0e0;border-radius:4px;overflow-x:auto;-webkit-overflow-scrolling:touch;',
      'code_block' => 'display:block;font-family:Roboto,"Courier New",Consolas,Inconsolata,Courier,monospace;font-size:14px;line-height:1.6;white-space:pre;color:#333;padding:16px;',

      'img'    => 'display:block;margin:12px auto;max-width:100%;',

      'table'  => 'display:table;border-collapse:collapse;border-spacing:0;text-align:left;margin:10px auto;border:0;',
      'thead'  => 'background-color:{{PRIMARY}};',
      'tr'     => 'border:0;border-top:1px solid #CCC;background-color:#fff;',
      'th'     => 'font-size:16px;border:1px solid {{PRIMARY}};padding:5px 10px;text-align:left;font-weight:bold;color:#eee;background-color:{{PRIMARY}};',
      'td'     => 'font-size:16px;border:1px solid #CCC;padding:5px 10px;text-align:left;'
    }.freeze

    # 李笑来原版 = 默认主题(同一套)
    LXL = DEFAULT

    # 按名查找
    BY_NAME = {
      '李笑来原版' => LXL
    }.freeze

    SUPPORTED_THEME_NAMES = BY_NAME.keys.freeze

    # ============================================================
    # 配色方案 (主色 + 加粗色)
    # ============================================================
    COLOR_SCHEMES = [
      { id: 'lxl_classic',  name: '青绿 · 深橙红(李笑来原版)', primary: LXL_GREEN,  bold: LXL_ORANGE },
      { id: 'blue_red',     name: '经典蓝 · 朱砂红',   primary: '#1e6bb8', bold: '#d63200' },
      { id: 'navy_orange',  name: '藏青 · 暖橙',       primary: '#1e3a8a', bold: '#ea580c' },
      { id: 'teal_magenta', name: '青碧 · 玫红',       primary: '#0f766e', bold: '#db2777' },
      { id: 'emerald_wine', name: '翡翠 · 酒红',       primary: '#059669', bold: '#9f1239' },
      { id: 'black_red',    name: '近黑 · 正红',       primary: '#111827', bold: '#dc2626' },
      { id: 'purple_amber', name: '紫罗兰 · 琥珀',     primary: '#6d28d9', bold: '#d97706' },
      { id: 'slate_coral',  name: '石墨 · 珊瑚红',     primary: '#334155', bold: '#e11d48' },
      { id: 'indigo_gold',  name: '靛蓝 · 金黄',       primary: '#4338ca', bold: '#ca8a04' }
    ].freeze

    COLOR_SCHEME_BY_ID = COLOR_SCHEMES.index_by { |s| s[:id] }.freeze
    DEFAULT_SCHEME = COLOR_SCHEMES.first.freeze

    def self.scheme_for(primary_hex, bold_hex)
      COLOR_SCHEMES.find { |s| s[:primary].casecmp?(primary_hex.to_s) && s[:bold].casecmp?(bold_hex.to_s) }
    end

    def self.scheme_by_id(id)
      COLOR_SCHEME_BY_ID[id.to_s]
    end

    def self.for(name)
      BY_NAME[name]
    end

    def self.supported?(name)
      BY_NAME.key?(name)
    end
  end
end
