require 'rails_helper'

RSpec.describe 'Api::V1::Articles', type: :request do
  let(:user) { create(:user) }
  let(:theme) do
    Theme.create!(
      name: '李笑来原版',
      css: '#wemd { font-size: 16px; }',
      is_builtin: true,
      wx_style_map: Wechat::ThemeStyleMaps::DEFAULT
    )
  end
  let(:token) { ApiToken.issue!(user, name: 'Typography spec').last }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'POST /api/v1/articles/preview' do
    it 'returns final inline typography without requiring a configured WeChat account' do
      user.update!(wx_typography_profile: 'standard_16')

      post '/api/v1/articles/preview',
           params: {
             markdown: "# 标题\n\n## 二级标题\n\n正文\n\n- 列表",
             theme_id: theme.id,
             typography_profile: 'readable_17'
           }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      fragment = Nokogiri::HTML::DocumentFragment.parse(json.fetch('html'))

      expect(json.dig('effective_typography', 'body_font_size')).to eq('17px')
      expect(fragment.at_css('p')['style']).to match(/font-size:17px/)
      expect(fragment.at_css('h2')['style']).to match(/font-size:21px/)
      expect(fragment.at_css('li')['style']).to match(/font-size:17px/)
    end

    it 'returns a clear error for an unsupported profile' do
      post '/api/v1/articles/preview',
           params: { markdown: '正文', typography_profile: 'large_18' }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to eq('invalid_typography_profile')
    end
  end
end
