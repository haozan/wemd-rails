require 'rails_helper'

RSpec.describe 'API health check', type: :request do
  around do |example|
    previous_revision = ENV['APP_REVISION']
    ENV['APP_REVISION'] = 'test-revision'
    example.run
  ensure
    previous_revision.nil? ? ENV.delete('APP_REVISION') : ENV['APP_REVISION'] = previous_revision
  end

  describe 'GET /api/v1/health' do
    it 'returns the running application revision' do
      get '/api/v1/health'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'status' => 'ok',
        'revision' => 'test-revision'
      )
    end
  end
end
