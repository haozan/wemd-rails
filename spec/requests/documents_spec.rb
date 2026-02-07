require 'rails_helper'

RSpec.describe "Documents", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  # index action 现在只支持 JSON API，不支持 HTML 视图

  describe "GET /documents/:id" do
    let(:document_record) { create(:document, user: user) }

    it "returns http success" do
      get document_path(document_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /documents/new" do
    it "returns http success" do
      get new_document_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /documents/:id/edit" do
    let(:document_record) { create(:document, user: user) }

    it "returns http success" do
      get edit_document_path(document_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /documents" do
    it "creates a new document" do
      post documents_path, params: { document: attributes_for(:document) }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /documents/:id" do
    let(:document_record) { create(:document, user: user) }

    it "updates the document" do
      patch document_path(document_record), params: { document: attributes_for(:document) }
      expect(response).to be_success_with_view_check
    end
  end
end
