class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy, :duplicate]
  before_action :authorize_document, only: [:edit, :update, :destroy, :duplicate]

  # 历史记录列表 API (仅 JSON)
  # turbo-architecture-validation: disable
  def index
    @documents = Current.user.documents.history_entries.limit(50)
    render json: @documents.as_json(
      only: [:title, :content, :saved_at, :created_at, :theme_id], 
      methods: [:friendly_id],
      include: { theme: { only: [:id, :name] } }
    ).map { |doc| doc.merge('id' => doc['friendly_id']).except('friendly_id') }
  end

  def show
    @theme = @document.theme || Theme.builtin.first
  end

  def new
    # 创建一个新的临时文档
    @document = Current.user.documents.build(
      title: '无标题文档',
      content: '# 无标题文档\n\n开始编写您的 Markdown 文档...',
      theme: Theme.builtin.first,
      is_auto_save: false
    )
    
    if @document.save
      redirect_to edit_document_path(@document)
    else
      redirect_to root_path, alert: '创建文档失败'
    end
  end

  def edit
    @themes = Theme.available_for_user(Current.user)
    @theme = @document.theme || Theme.builtin.first
    @documents = Current.user.documents.history_entries.limit(50)
  end

  # turbo-architecture-validation: disable
  def create
    @document = Current.user.documents.build(document_params)
    @document.is_auto_save = false
    
    if @document.save
      Document.cleanup_old_entries(Current.user)
      
      respond_to do |format|
        format.html { redirect_to edit_document_path(@document) }
        format.json { 
          render json: { 
            success: true, 
            id: @document.friendly_id, 
            document: {
              id: @document.friendly_id,
              title: @document.title, 
              saved_at: @document.saved_at
            } 
          } 
        }
      end
    else
      respond_to do |format|
        format.html do
          @themes = Theme.available_for_user(Current.user)
          render :new, status: :unprocessable_entity
        end
        format.json { render json: { success: false, errors: @document.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # turbo-architecture-validation: disable
  def update
    # 不再修改 is_auto_save 字段，保持文档在创建时的状态
    # 所有用户创建的文档都会显示在文章目录中
    
    if @document.update(document_params)
      Document.cleanup_old_entries(Current.user)
      
      respond_to do |format|
        # 自动保存：静默更新，不重定向
        format.html { render plain: 'OK', status: :ok }
        format.json { 
          render json: { 
            success: true, 
            document: {
              id: @document.friendly_id,
              title: @document.title, 
              saved_at: @document.saved_at 
            }
          } 
        }
      end
    else
      respond_to do |format|
        format.html do
          @themes = Theme.available_for_user(Current.user)
          render :edit, status: :unprocessable_entity
        end
        format.json { render json: { success: false, errors: @document.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # turbo-architecture-validation: disable
  def destroy
    # 保护演示文章不被删除
    if @document.slug == 'welcome'
      respond_to do |format|
        format.html { redirect_to edit_document_path(@document), alert: "演示文章不能删除" }
        format.json { render json: { success: false, error: "演示文章不能删除" }, status: :forbidden }
      end
      return
    end
    
    @document.destroy
    
    respond_to do |format|
      format.html { redirect_to root_path, notice: "文档已删除" }
      format.json { render json: { success: true } }
    end
  end

  # 复制文档
  # turbo-architecture-validation: disable
  def duplicate
    # 创建副本
    @new_document = @document.dup
    @new_document.title = "#{@document.title} - 副本"
    @new_document.is_auto_save = false
    @new_document.slug = nil # 清空 slug，让 FriendlyId 重新生成
    
    if @new_document.save
      Document.cleanup_old_entries(Current.user)
      
      respond_to do |format|
        format.json do
          render json: {
            success: true,
            document: {
              id: @new_document.friendly_id,
              title: @new_document.title,
              content: @new_document.content,
              saved_at: @new_document.saved_at,
              theme_id: @new_document.theme_id,
              theme: @new_document.theme ? @new_document.theme.as_json(only: [:id, :name]) : nil
            }
          }
        end
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @new_document.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # 清空历史记录
  # turbo-architecture-validation: disable
  def clear_history
    # 删除所有文档，但保留演示文章
    Current.user.documents.where.not(slug: 'welcome').destroy_all
    
    respond_to do |format|
      format.html { redirect_to root_path, notice: "历史记录已清空" }
      format.json { render json: { success: true } }
    end
  end

  private

  def set_document
    @document = Current.user.documents.friendly.find(params[:id])
  end

  # turbo-architecture-validation: disable
  def authorize_document
    unless @document.user == Current.user
      respond_to do |format|
        format.html { redirect_to root_path, alert: "无权操作该文档" }
        format.json { render json: { success: false, error: "无权操作" }, status: :forbidden }
      end
    end
  end

  def document_params
    params.require(:document).permit(:title, :content, :theme_id)
  end
end
