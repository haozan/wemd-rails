require 'rails_helper'

RSpec.describe "WeMD Editor Table UI", type: :request do
  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }
  let(:document) { create(:document, user: user) }

  describe "GET /documents/:id/edit" do
    it "编辑页面包含表格按钮" do
      get edit_document_path(document)
      expect(response.body).to include('data-action="click->wemd-editor#insertTable"')
      expect(response.body).to include('title="表格"')
    end
  end
end

RSpec.describe "WeMD Editor Table TypeScript", type: :feature do
  describe "TypeScript 编译结果" do
    it "JavaScript 文件包含 insertTable 方法" do
      js_file = Rails.root.join('app/assets/builds/application.js')
      expect(File.exist?(js_file)).to be true
      
      content = File.read(js_file)
      expect(content).to include('insertTable')
    end

    it "TypeScript 文件包含完整的表格插入实现" do
      ts_file = Rails.root.join('app/javascript/controllers/wemd_editor_controller.ts')
      expect(File.exist?(ts_file)).to be true
      
      content = File.read(ts_file)
      expect(content).to include('insertTable()')
      expect(content).to include('表头 1')
      expect(content).to include('表头 2')
      expect(content).to include('表头 3')
      expect(content).to include('单元格')
    end
  end
end
