require 'rails_helper'

RSpec.describe Wechat::StyleRenderer do
  def final_property(node, property)
    node['style'].to_s.scan(/(?:\A|;)\s*#{Regexp.escape(property)}\s*:\s*([^;]+)/).flatten.last
  end

  it 'writes the readable profile after theme and source inline styles' do
    renderer = described_class.new(
      { '_root' => 'font-size:12px;', 'p' => 'font-size:13px;line-height:1.2;' },
      typography_profile: 'readable_17'
    )

    fragment = Nokogiri::HTML::DocumentFragment.parse(
      renderer.render('<p style="font-size:9px;line-height:1">正文</p>')
    )
    root = fragment.at_css('section.wemd-article')
    paragraph = fragment.at_css('p')

    expect(final_property(root, 'font-size')).to eq('17px')
    expect(final_property(paragraph, 'font-size')).to eq('17px')
    expect(final_property(paragraph, 'line-height')).to eq('1.75')
    expect(paragraph['style']).not_to include('font-size:9px')
  end

  it 'uses smaller semantic sizes for quotes, captions, footnotes, and code' do
    html = <<~HTML
      <blockquote><p>引用</p></blockquote>
      <figure><figcaption>图注</figcaption></figure>
      <section class="footnotes"><ol><li class="footnote-item">脚注</li></ol></section>
      <p><code>inline</code></p>
    HTML
    fragment = Nokogiri::HTML::DocumentFragment.parse(
      described_class.new({}, typography_profile: 'readable_17').render(html)
    )

    expect(final_property(fragment.at_css('blockquote p'), 'font-size')).to eq('16px')
    expect(final_property(fragment.at_css('figcaption'), 'font-size')).to eq('14px')
    expect(final_property(fragment.at_css('.footnote-item'), 'font-size')).to eq('14px')
    expect(final_property(fragment.at_css('p code'), 'font-size')).to eq('14px')
  end

  it 'can enforce typography on HTML already inlined by a legacy theme' do
    renderer = described_class.new({}, typography_profile: 'standard_16')
    html = '<section class="wemd-article" style="font-size:11px"><p style="font-size:12px">正文</p></section>'
    fragment = Nokogiri::HTML::DocumentFragment.parse(renderer.apply_typography(html))

    expect(final_property(fragment.at_css('section'), 'font-size')).to eq('16px')
    expect(final_property(fragment.at_css('p'), 'font-size')).to eq('16px')
  end
end
