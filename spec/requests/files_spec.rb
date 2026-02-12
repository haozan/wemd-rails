require 'rails_helper'

RSpec.describe "Files", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /files/:id" do
    let(:file_record) { create(:file) }

    it "returns http success" do
      get file_path(file_record)
      expect(response).to be_success_with_view_check('show')
    end
  end
end
