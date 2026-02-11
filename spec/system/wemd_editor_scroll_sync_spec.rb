require 'rails_helper'

RSpec.describe "WeMD Editor Scroll Sync", type: :request do
  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }
  let(:document) { create(:document, user: user) }

  describe "GET /documents/:id/edit" do
    it "预览区包含 previewContent target" do
      get edit_document_path(document)
      expect(response.body).to include('data-wemd-editor-target="preview previewContent"')
    end
  end
end

RSpec.describe "WeMD Editor Scroll Sync TypeScript", type: :feature do
  describe "TypeScript 编译结果" do
    it "JavaScript 文件包含 setupScrollSync 方法" do
      js_file = Rails.root.join('app/assets/builds/application.js')
      expect(File.exist?(js_file)).to be true
      
      content = File.read(js_file)
      expect(content).to include('setupScrollSync')
    end

    it "JavaScript 文件包含 handleEditorScroll 方法" do
      js_file = Rails.root.join('app/assets/builds/application.js')
      expect(File.exist?(js_file)).to be true
      
      content = File.read(js_file)
      expect(content).to include('handleEditorScroll')
    end

    it "TypeScript 文件包含完整的滚动同步实现" do
      ts_file = Rails.root.join('app/javascript/controllers/wemd_editor_controller.ts')
      expect(File.exist?(ts_file)).to be true
      
      content = File.read(ts_file)
      expect(content).to include('setupScrollSync()')
      expect(content).to include('handleEditorScroll')
      expect(content).to include('isSyncingScroll')
      expect(content).to include('scrollPercentage')
      expect(content).to include('.wemd-preview-content')
    end
  end
end
