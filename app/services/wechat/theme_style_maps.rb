# frozen_string_literal: true

# 内置主题的 wx_style_map 配置(用于 Wechat::StyleRenderer)
#
# 约定:
#   - 每个 key 是 HTML 标签名(小写),值是内联 CSS 字符串
#   - {{PRIMARY}} 占位符会被 StyleRenderer 替换成用户选择的主色
#   - 特殊 key:
#       _root            最外层 section 样式
#       _code_theme      Rouge 高亮主题名(github/monokai/base16.dark)
#       _default_primary 该主题在用户未选色时的默认主色
#       code_inline      行内 <code>
#       code_block       <pre> 内的 <code>
#
# 三个主题共享底座(wemd 经典排版),差异主要靠主色和少量细节区分。

module Wechat
  module ThemeStyleMaps
    # === 默认主题:李笑来原版(Markdown Here Classic)高保真移植 ===
    # 关键特征:
    #   - 行高 1.8em,字间距 0.1em(原版最显著的识别特征)
    #   - 段落 text-align: justify(两端对齐)
    #   - 标题全部"居中" + 青绿色 #009688
    #   - H1/H2 带底部细线(#ddd / #eee)
    #   - strong = 深橙红 #BF360C / em = 青绿 #009688
    #   - hr 分隔线 = 深橙红 #BF360C
    #   - blockquote 左边 2px 青绿线,灰色文字 #777
    #   - ul 使用空心圆点(circle)
    #   - 表格 th = 青绿底 + 白字
    #
    # 注意:原版本身不依赖 {{PRIMARY}},颜色是固定的;
    # 保留 {{BOLD}} 让用户可微调"加粗强调色"(默认 #BF360C).
    # _default_primary 设为青绿,用户切换配色方案时只影响链接/行内代码色.
    LXL_GREEN  = '#009688'   # 李笑来标志青绿(em / 标题 / 引用边框 / 表头)
    LXL_ORANGE = '#BF360C'   # 李笑来标志深橙红(strong 默认 / hr)

    DEFAULT = {
      '_root'            => "font-size:16px;color:#000;line-height:1.8;letter-spacing:0.1em;word-break:break-word;font-family:Optima-Regular,Optima,PingFangSC-light,PingFangTC-light,'PingFang SC','Microsoft YaHei','微软雅黑','Segoe UI',Roboto,Helvetica,Arial,sans-serif;",
      '_code_theme'      => 'github',
      '_default_primary' => LXL_GREEN,   # 原版青绿

      # 段落:两端对齐 + 1.8 行高(原版最鲜明的排版特征)
      'p'      => 'font-size:16px;line-height:1.8;letter-spacing:0.1em;margin:1.5em 5px;color:#000;text-align:justify;',

      # 标题:全部居中 + {{PRIMARY}}(原版默认青绿,跟随用户配色方案)
      'h1'     => 'font-size:24px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;border-bottom:1px solid #ddd;',
      'h2'     => 'font-size:20px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;border-bottom:1px solid #eee;',
      'h3'     => 'font-size:18px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',
      'h4'     => 'font-size:16px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',
      'h5'     => 'font-size:16px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',
      'h6'     => 'font-size:16px;font-weight:bold;color:{{PRIMARY}};margin:1.5em 5px;padding:0.5em 1em;text-align:center;',

      # strong:加粗色(默认深橙红,跟随用户配色方案)
      'strong' => 'font-weight:bold;color:{{BOLD}};',

      # em:与标题同色({{PRIMARY}})
      'em'     => 'font-style:italic;color:{{PRIMARY}};',
      'del'    => 'font-style:italic;color:#000;text-decoration:line-through;',

      # 链接:跟随主色
      'a'      => 'color:{{PRIMARY}};text-decoration:none;font-weight:bold;border-bottom:1px solid {{PRIMARY}};',

      # 引用:2px 主色左边框 + 灰色文字 + 透明背景 + 左缩进(原版特征)
      'blockquote' => 'display:block;border-left:2px solid {{PRIMARY}};background:transparent;color:#777;padding:0 10px;margin:10px 5px 10px 1em;font-size:16px;',

      # 列表:原版使用空心圆点
      'ul'     => 'padding-left:15px;margin:10px 5px;color:#000;list-style-type:circle;',
      'ol'     => 'padding-left:15px;margin:10px 5px;color:#000;list-style-type:decimal;',
      'li'     => 'line-height:1.8;letter-spacing:0.1em;margin:10px;color:#010101;',

      # 分隔线:加粗色(原版标志特征,默认深橙红)
      'hr'     => 'height:0;margin:1.5em auto;border:none;border-top:1px solid {{BOLD}};',

      # 行内代码:跟随主色
      'code_inline' => 'font-size:14px;padding:2px 4px;border-radius:2px;margin:0 2px;color:{{PRIMARY}};background-color:rgba(27,31,35,0.05);font-family:Roboto,"Courier New",Consolas,Inconsolata,Courier,monospace;word-break:break-all;',

      # 代码块:15px / 1.4 行高(原版规范)
      'pre'        => 'margin:1em 5px;padding:0;background:#f8f8f8;border:1px solid #e0e0e0;border-radius:4px;overflow-x:auto;-webkit-overflow-scrolling:touch;',
      'code_block' => 'display:block;font-family:Roboto,"Courier New",Consolas,Inconsolata,Courier,monospace;font-size:15px;line-height:1.4;white-space:pre;color:#24292e;padding:16px;border-radius:3px;',

      'img'    => 'display:block;margin:12px auto;max-width:100%;',

      # 表格:主色表头(原版青绿特征,跟随用户配色)
      'table'  => 'display:table;border-collapse:collapse;border-spacing:0;text-align:left;margin:10px auto;border:0;',
      'thead'  => 'background-color:{{PRIMARY}};',
      'tr'     => 'border:0;border-top:1px solid #CCC;background-color:#fff;',
      'th'     => 'font-size:16px;border:1px solid {{PRIMARY}};padding:5px 10px;text-align:left;font-weight:bold;color:#eee;background-color:{{PRIMARY}};',
      'td'     => 'font-size:16px;border:1px solid #CCC;padding:5px 10px;text-align:left;'
    }.freeze

    # === 李笑来原版:与默认主题同源(同样工具书风格) ===
    LXL = DEFAULT

    # === 知识库:结构化、清晰,H2 带主色下划线、列表缩进明显 ===
    KB = DEFAULT.merge(
      '_default_primary' => '#2563eb',   # 知识库偏蓝

      'p'      => 'font-size:15px;line-height:1.8;margin:12px 0;color:#222;',

      # 标题视觉层级更清晰:H1 居中加底色,H2 主色下划线,H3 主色前缀感
      'h1'     => 'font-size:22px;font-weight:bold;color:#fff;background:{{PRIMARY}};margin:28px 0 18px;padding:10px 16px;border-radius:4px;text-align:center;',
      'h2'     => 'font-size:20px;font-weight:bold;color:#000;margin:26px 0 14px;padding:0 0 6px 0;border-bottom:2px solid {{PRIMARY}};',
      'h3'     => 'font-size:18px;font-weight:bold;color:{{PRIMARY}};margin:22px 0 12px;padding:0 0 0 10px;border-left:3px solid {{PRIMARY}};',
      'h4'     => 'font-size:16px;font-weight:bold;color:#333;margin:18px 0 10px;',

      'strong' => 'font-weight:bold;color:{{BOLD}};',

      'blockquote' => 'display:block;border-left:4px solid {{PRIMARY}};background:#f0f7ff;color:#334;padding:12px 20px;margin:20px 0;font-size:15px;',

      # 列表缩进清晰,子项有点感
      'ul'     => 'padding-left:28px;margin:10px 0;color:#222;list-style-type:disc;',
      'ol'     => 'padding-left:28px;margin:10px 0;color:#222;list-style-type:decimal;',
      'li'     => 'line-height:1.8;margin:8px 0;color:#222;',

      # 表格头用主色淡色
      'th'     => 'font-size:15px;border:1px solid #d0d7de;padding:8px 12px;text-align:left;font-weight:bold;background-color:#f0f7ff;color:#000;',
      'td'     => 'font-size:15px;border:1px solid #d0d7de;padding:8px 12px;text-align:left;'
    ).freeze

    # 按 name 查找(取不到返回 nil,会走 premailer 兜底)
    BY_NAME = {
      '默认主题'   => DEFAULT,
      '李笑来原版' => LXL,
      '知识库'     => KB
    }.freeze

    # 微信草稿同步允许使用的主题名白名单
    SUPPORTED_THEME_NAMES = BY_NAME.keys.freeze

    # ============================================================
    # 配色方案 (主色 + 加粗色)
    # 用户只选择 scheme_id, 后端把 primary/bold 写入 user 记录
    # 两种颜色要形成对比:主色常用于链接/引用边框/标题点缀(偏中性或冷),
    # 加粗色用于 <strong>(偏暖/高饱和), 让"重点文字"跳出来
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
