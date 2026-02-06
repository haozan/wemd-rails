class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy]
  before_action :authorize_document, only: [:edit, :update, :destroy]

  def index
    @documents = Current.user.documents.recent.page(params[:page]).per(20)
  end

  def show
    # @document 已由 before_action 设置
    @theme = @document.theme || Theme.builtin.first
  end

  def new
    @document = Current.user.documents.build
    @themes = Theme.available_for_user(Current.user)
  end

  def edit
    @themes = Theme.available_for_user(Current.user)
    @theme = @document.theme || Theme.builtin.first
  end

  def create
    @document = Current.user.documents.build(document_params)
    
    if @document.save
      redirect_to edit_document_path(@document), notice: "文档创建成功"
    else
      @themes = Theme.available_for_user(Current.user)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @document.update(document_params)
      redirect_to edit_document_path(@document), notice: "文档已保存"
    else
      @themes = Theme.available_for_user(Current.user)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy
    redirect_to documents_path, notice: "文档已删除"
  end

  private

  def set_document
    @document = Document.friendly.find(params[:id])
  end

  def authorize_document
    unless @document.user == Current.user
      redirect_to documents_path, alert: "无权操作该文档"
    end
  end

  def document_params
    params.require(:document).permit(:title, :content, :theme_id)
  end
end
