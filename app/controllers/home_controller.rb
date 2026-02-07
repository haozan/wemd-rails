class HomeController < ApplicationController
  include HomeDemoConcern

  def index
    # 显示落地页，所有用户都可以访问
  end

  # 开始创作 - 智能跳转逻辑
  def start_writing
    # 未登录用户跳转到注册页
    unless user_signed_in?
      redirect_to sign_up_path, alert: '请先注册或登录'
      return
    end

    # 已登录用户：检查是否有创作记录（排除 welcome 演示文章）
    latest_document = Current.user.documents.where.not(slug: 'welcome').order(updated_at: :desc).first
    
    if latest_document.present?
      # 有创作记录，进入最新的文章
      redirect_to edit_document_path(latest_document)
    else
      # 新用户或只有演示文章，进入 welcome 演示文章
      welcome_document = Document.find_or_create_welcome_document(Current.user)
      redirect_to edit_document_path(welcome_document)
    end
  end
end
