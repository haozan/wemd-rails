require 'rails_helper'

RSpec.describe "WeMD Editor Undo/Redo UI", type: :request do
  let(:user) { create(:user, password: 'password123') }
  let(:document) { create(:document, user: user, title: "测试文档", content: "初始内容") }

  before do
    sign_in_as(user)
  end

  describe "GET /documents/:id/edit" do
    it "编辑页面包含撤销按钮" do
      get edit_document_path(document)
      expect(response.body).to include('data-action="click->wemd-editor#undo"')
      expect(response.body).to include('撤销')
    end

    it "编辑页面包含重做按钮" do
      get edit_document_path(document)
      expect(response.body).to include('data-action="click->wemd-editor#redo"')
      expect(response.body).to include('重做')
    end
  end
end

RSpec.describe "WeMD Editor Undo/Redo TypeScript", type: :feature do
  describe "TypeScript 编译结果" do
    it "JavaScript 文件包含 undo 和 redo 方法" do
      js_content = File.read(Rails.root.join('app/assets/builds/application.js'))
      
      # 检查 undo 和 redo 方法是否存在
      expect(js_content).to include('undo')
      expect(js_content).to include('redo')
      expect(js_content).to include('history')
      expect(js_content).to include('historyIndex')
    end

    it "TypeScript 文件包含完整的撤销/重做实现" do
      ts_content = File.read(Rails.root.join('app/javascript/controllers/wemd_editor_controller.ts'))
      
      # 检查关键方法
      expect(ts_content).to include('undo(): void')
      expect(ts_content).to include('redo(): void')
      expect(ts_content).to include('saveToHistory(): void')
      expect(ts_content).to include('restoreFromHistory(): void')
      expect(ts_content).to include('setupKeyboardShortcuts(): void')
      
      # 检查历史记录属性
      expect(ts_content).to include('private history:')
      expect(ts_content).to include('private historyIndex:')
      expect(ts_content).to include('private isRestoringHistory:')
    end
  end
end
