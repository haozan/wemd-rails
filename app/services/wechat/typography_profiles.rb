# frozen_string_literal: true

module Wechat
  # 微信文章的统一排版档位。
  #
  # 这里是正文尺寸的唯一真源：编辑器预览、复制、Web 同步和 Personal API
  # 都只传 profile id，由服务端把字号与行高写入最终 HTML 的内联 style。
  module TypographyProfiles
    class UnknownProfile < ArgumentError; end

    DEFAULT_ID = 'readable_17'

    PROFILES = {
      'compact_15' => {
        id: 'compact_15',
        name: '紧凑阅读',
        body_font_size: '15px',
        line_height: '1.70',
        h1_font_size: '22px',
        h2_font_size: '19px',
        h3_font_size: '17px',
        h4_font_size: '15px',
        quote_font_size: '15px',
        table_font_size: '14px',
        caption_font_size: '13px',
        code_font_size: '13px'
      }.freeze,
      'standard_16' => {
        id: 'standard_16',
        name: '标准阅读',
        body_font_size: '16px',
        line_height: '1.75',
        h1_font_size: '23px',
        h2_font_size: '20px',
        h3_font_size: '18px',
        h4_font_size: '16px',
        quote_font_size: '15px',
        table_font_size: '15px',
        caption_font_size: '13px',
        code_font_size: '14px'
      }.freeze,
      'readable_17' => {
        id: 'readable_17',
        name: '舒适阅读',
        body_font_size: '17px',
        line_height: '1.75',
        h1_font_size: '24px',
        h2_font_size: '21px',
        h3_font_size: '19px',
        h4_font_size: '17px',
        quote_font_size: '16px',
        table_font_size: '16px',
        caption_font_size: '14px',
        code_font_size: '14px'
      }.freeze
    }.freeze

    PUBLIC_KEYS = %i[
      id name body_font_size line_height h1_font_size h2_font_size h3_font_size
      h4_font_size quote_font_size table_font_size caption_font_size code_font_size
    ].freeze

    module_function

    def ids
      PROFILES.keys
    end

    def all
      PROFILES.values
    end

    def valid?(id)
      PROFILES.key?(id.to_s)
    end

    def fetch(id = nil)
      normalized_id = id.to_s.strip
      normalized_id = DEFAULT_ID if normalized_id.empty?
      PROFILES.fetch(normalized_id)
    rescue KeyError
      raise UnknownProfile, normalized_id
    end

    def public_payload(id = nil)
      fetch(id).slice(*PUBLIC_KEYS)
    end

    def label(id = nil)
      profile = fetch(id)
      "#{profile[:name]} · #{profile[:body_font_size]} / #{profile[:line_height]}"
    end

    # 返回应追加到元素现有 style 末尾的排版声明，确保排版档位优先于主题值。
    def inline_style(id, key)
      profile = fetch(id)

      case key.to_s
      when '_root', 'p', 'ul', 'ol', 'li'
        "font-size:#{profile[:body_font_size]};line-height:#{profile[:line_height]};"
      when 'h1'
        "font-size:#{profile[:h1_font_size]};line-height:1.4;"
      when 'h2'
        "font-size:#{profile[:h2_font_size]};line-height:1.45;"
      when 'h3'
        "font-size:#{profile[:h3_font_size]};line-height:1.5;"
      when 'h4', 'h5', 'h6'
        "font-size:#{profile[:h4_font_size]};line-height:1.55;"
      when 'blockquote'
        "font-size:#{profile[:quote_font_size]};line-height:#{profile[:line_height]};"
      when 'table', 'th', 'td'
        "font-size:#{profile[:table_font_size]};line-height:1.6;"
      when 'figcaption', 'footnote'
        "font-size:#{profile[:caption_font_size]};line-height:1.65;"
      when 'code_inline'
        "font-size:#{profile[:code_font_size]};line-height:1.6;"
      when 'code_block'
        "font-size:#{profile[:code_font_size]};line-height:1.6;"
      end
    end
  end
end
