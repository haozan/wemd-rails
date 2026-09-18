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

  describe 'GET /api/v1/articles/wechat_config_status' do
    it 'reports AppID, AppSecret, server IP, and whitelist success independently' do
      user.update!(wechat_app_id: 'wx123', wechat_app_secret: 'secret')
      sync_service = instance_double(Wechat::SyncService, ready?: true, access_token: 'wx-access-token')
      allow(Wechat::SyncService).to receive(:new).with(user).and_return(sync_service)

      get '/api/v1/articles/wechat_config_status', headers: headers.except('Content-Type')

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        'configuration_ok' => true,
        'app_id_configured' => true,
        'app_secret_configured' => true,
        'app_id_ok' => true,
        'app_secret_ok' => true,
        'ip_whitelist_ok' => true,
        'server_ip' => Wechat::SyncService::SERVER_IP
      )
    end

    it 'identifies an IP whitelist failure without exposing credentials' do
      user.update!(wechat_app_id: 'wx123', wechat_app_secret: 'secret')
      sync_service = instance_double(Wechat::SyncService, ready?: true)
      allow(sync_service).to receive(:access_token)
        .and_raise(Wechat::SyncService::SyncError, 'IP 未在微信公众号后台白名单中！(极其重要)')
      allow(Wechat::SyncService).to receive(:new).with(user).and_return(sync_service)

      get '/api/v1/articles/wechat_config_status', headers: headers.except('Content-Type')

      json = JSON.parse(response.body)
      expect(json).to include(
        'configuration_ok' => false,
        'app_id_ok' => true,
        'app_secret_ok' => true,
        'ip_whitelist_ok' => false
      )
      expect(json).not_to have_key('wechat_app_id')
      expect(json).not_to have_key('wechat_app_secret')
    end
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
