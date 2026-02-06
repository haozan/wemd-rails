require 'rails_helper'

RSpec.describe "Api::Uploads", type: :request do
  let(:user) { create(:user) }
  let(:session) { Session.create!(user: user, user_agent: 'test', ip_address: '127.0.0.1') }
  let(:auth_token) { session.id }

  describe "POST /api/uploads" do
    context "with valid authentication and valid file" do
      let(:file) { fixture_file_upload('test_image.jpg', 'image/jpeg') }

      before do
        # Create a test image file
        File.write(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg'), 'fake image content')
      end

      it "uploads the image and returns success" do
        post api_uploads_path, params: { file: file }, headers: { 'Authorization' => "Bearer #{auth_token}" }
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['url']).to be_present
        expect(json_response['filename']).to be_present
      end
    end

    context "without authentication" do
      let(:file) { fixture_file_upload('test_image.jpg', 'image/jpeg') }

      it "returns unauthorized" do
        post api_uploads_path, params: { file: file }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "without file parameter" do
      it "returns unprocessable entity" do
        post api_uploads_path, headers: { 'Authorization' => "Bearer #{auth_token}" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('请选择要上传的图片')
      end
    end
  end
end
