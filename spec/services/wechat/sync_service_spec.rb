require 'rails_helper'

RSpec.describe Wechat::SyncService do
  def final_property(node, property)
    node['style'].to_s.scan(/(?:\A|;)\s*#{Regexp.escape(property)}\s*:\s*([^;]+)/).flatten.last
  end

  it 'enforces the user profile even for legacy CSS-only themes' do
    user = build_stubbed(:user, wx_typography_profile: 'readable_17')
    theme = build_stubbed(:theme, css: '#wemd p { font-size: 12px; line-height: 1.2; }', wx_style_map: nil)
    document = Struct.new(:content, :theme, :title).new('正文', theme, '测试')

    html = described_class.new(user).render_preview_html(document)
    paragraph = Nokogiri::HTML::DocumentFragment.parse(html).at_css('p')

    expect(final_property(paragraph, 'font-size')).to eq('17px')
    expect(final_property(paragraph, 'line-height')).to eq('1.75')
  end
end
