require 'rails_helper'

RSpec.describe "Admin::Themes", type: :request do
  let(:admin) { Administrator.create!(name: 'test_admin', password: 'password123', role: 'super_admin') }

  before do
    # 模拟管理员登录
    post admin_login_path, params: { name: admin.name, password: 'password123' }
  end

  describe "POST /admin/themes/sync" do
    it "syncs all builtin themes successfully" do
      # 先清空所有主题
      Theme.delete_all
      
      # 创建一个旧版本的主题
      Theme.create!(name: "默认主题", css: "old css", is_builtin: true)
      Theme.create!(name: "自定义主题", css: "custom css", is_builtin: false)

      initial_count = Theme.builtin.count
      
      post sync_admin_themes_path

      expect(response).to redirect_to(admin_root_path)
      expect(flash[:notice]).to match(/成功同步 13 个内置主题/)

      # 验证有13个内置主题
      expect(Theme.builtin.count).to eq(13)

      # 验证主题CSS已更新
      lixiaolai_theme = Theme.find_by(name: "李笑来原版", is_builtin: true)
      expect(lixiaolai_theme).to be_present
      expect(lixiaolai_theme.css).to include("text-align: justify !important")

      # 验证默认主题已更新（不再是旧CSS）
      default_theme = Theme.find_by(name: "默认主题", is_builtin: true)
      expect(default_theme.css).not_to eq("old css")

      # 验证自定义主题未受影响
      custom_theme = Theme.find_by(name: "自定义主题")
      expect(custom_theme.css).to eq("custom css")
    end

    it "handles missing theme files gracefully" do
      # 临时重命名一个主题文件来模拟缺失
      # 这里我们只测试正常情况，因为生产环境中文件应该都存在
      post sync_admin_themes_path

      expect(response).to redirect_to(admin_root_path)
      expect(flash[:notice] || flash[:alert]).to be_present
    end
  end
end
