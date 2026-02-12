require 'rails_helper'

RSpec.describe "Admin::Themes", type: :request do
  before { admin_sign_in_as(create(:administrator)) }

  describe "GET /admin/themes" do
    it "returns http success" do
      get admin_themes_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "POST /admin/themes/sync_builtin_themes" do
    it "syncs all builtin themes from CSS files" do
      # Modify one theme's CSS to test update
      theme = Theme.find_by(name: "李笑来原版")
      original_css = theme.css
      theme.update!(css: "/* modified */")
      
      # Remove one theme to test creation
      deleted_theme = Theme.find_by(name: "主题模板")
      deleted_theme.destroy!
      
      expect {
        post sync_builtin_themes_admin_themes_path
      }.to change { Theme.count }.by(1)
      
      # Check redirect
      expect(response).to redirect_to(admin_themes_path)
      expect(flash[:notice]).to match(/同步完成/)
      
      # Check the modified theme was updated
      theme.reload
      expect(theme.css).to include(".footnote-item a")
      expect(theme.css).not_to eq("/* modified */")
      
      # Check all 13 themes exist
      expect(Theme.where(is_builtin: true).count).to eq(13)
    end
  end

end
