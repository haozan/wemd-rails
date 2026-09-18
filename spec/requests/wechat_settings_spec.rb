require 'rails_helper'

RSpec.describe 'WeChat settings', type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe 'GET /profile/wechat_settings' do
    it 'renders a prominent platform link and persistent test feedback region' do
      get wechat_settings_profile_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('打开微信开发者平台')
      expect(response.body).to include('target="_blank"')
      expect(response.body).to include('data-controller="wechat-connection"')
      expect(response.body).to include('data-wechat-connection-target="result"')
      expect(response.body).to include('aria-live="polite"')
    end
  end
end
