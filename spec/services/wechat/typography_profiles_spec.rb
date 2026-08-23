require 'rails_helper'

RSpec.describe Wechat::TypographyProfiles do
  it 'uses readable 17px as the default profile' do
    profile = described_class.fetch

    expect(profile[:id]).to eq('readable_17')
    expect(profile[:body_font_size]).to eq('17px')
    expect(profile[:line_height]).to eq('1.75')
  end

  it 'defines three stable public profile ids' do
    expect(described_class.ids).to eq(%w[compact_15 standard_16 readable_17])
  end

  it 'rejects unknown profiles instead of silently changing typography' do
    expect { described_class.fetch('large_18') }
      .to raise_error(described_class::UnknownProfile, 'large_18')
  end
end
