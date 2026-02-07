class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy, :restore]
  before_action :authorize_document, only: [:edit, :update, :destroy]

  # 历史记录列表 API (仅 JSON)
  # turbo-architecture-validation: disable
  def index
    @documents = Current.user.documents.history_entries.limit(50)
    render json: @documents.as_json(only: [:id, :title, :content, :saved_at, :created_at, :theme_id], include: { theme: { only: [:id, :name] } })
  end

  def show
    @theme = @document.theme || Theme.builtin.first
  end

  def new
    @document = Current.user.documents.build(title: "新文章", content: "# 新文章\n\n")
    @themes = Theme.available_for_user(Current.user)
    # 设置默认主题（第一个内置主题）
    @theme = Theme.builtin.first
    @document.theme_id = @theme&.id
  end

  def edit
    @themes = Theme.available_for_user(Current.user)
    @theme = @document.theme || Theme.builtin.first
    @documents = Current.user.documents.history_entries.limit(50)
  end

  def create
    @document = Current.user.documents.build(document_params)
    @document.is_auto_save = false
    
    if @document.save
      Document.cleanup_old_entries(Current.user)
      redirect_to edit_document_path(@document), notice: "文档创建成功"
    else
      @themes = Theme.available_for_user(Current.user)
      render :new, status: :unprocessable_entity
    end
  end

  # turbo-architecture-validation: disable
  def update
    @document.is_auto_save = params[:auto_save] == "true"
    
    if @document.update(document_params)
      Document.cleanup_old_entries(Current.user)
      
      respond_to do |format|
        format.html { redirect_to edit_document_path(@document), notice: "文档已保存" }
        format.json { render json: { success: true, document: @document.as_json(only: [:id, :title, :saved_at]) } }
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
    @document.destroy
    
    respond_to do |format|
      format.html { redirect_to root_path, notice: "文档已删除" }
      format.json { render json: { success: true } }
    end
  end

  # 恢复历史记录
  # turbo-architecture-validation: disable
  def restore
    respond_to do |format|
      format.json do
        render json: {
          success: true,
          document: @document.as_json(
            only: [:id, :title, :content, :saved_at, :theme_id],
            include: { theme: { only: [:id, :name, :css] } }
          )
        }
      end
    end
  end

  # 清空历史记录
  # turbo-architecture-validation: disable
  def clear_history
    Current.user.documents.destroy_all
    
    respond_to do |format|
      format.html { redirect_to root_path, notice: "历史记录已清空" }
      format.json { render json: { success: true } }
    end
  end

  private

  def set_document
    @document = Document.friendly.find(params[:id])
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
