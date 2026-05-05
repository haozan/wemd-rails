class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :edit, :update, :destroy, :duplicate, :sync_to_wechat]
  before_action :authorize_document, only: [:edit, :update, :destroy, :duplicate, :sync_to_wechat]

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
    # 创建一个新的文档，标题包含时间戳以便识别
    timestamp = Time.current.strftime('%m月%d日 %H:%M')
    default_title = "新文档 #{timestamp}"
    
    @document = Current.user.documents.build(
      title: default_title,
      content: "# #{default_title}\n\n开始编写您的 Markdown 文档...",
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
    
    # 在删除前查找替代文档
    # 优先选择最近更新的其他文档
    replacement_document = Current.user.documents
                                        .where.not(id: @document.id)
                                        .order(updated_at: :desc)
                                        .first
    
    @document.destroy
    
    respond_to do |format|
      format.html do
        if replacement_document
          # 有其他文档，跳转到替代文档的编辑页
          redirect_to edit_document_path(replacement_document), notice: "文档已删除"
        else
          # 没有其他文档了，跳转到首页
          redirect_to root_path, notice: "文档已删除"
        end
      end
      format.json do
        render json: { 
          success: true,
          redirect_to: replacement_document ? edit_document_path(replacement_document) : root_path
        }
      end
    end
  end

  # 复制文档
  # turbo-architecture-validation: disable
  def sync_to_wechat
    sync_service = Wechat::SyncService.new(Current.user)
    
    unless sync_service.ready?
      return render json: { 
        success: false, 
        message: "尚未配置微信公众号参数，请先前往『账号设置 -> 微信公众号配置』进行配置。",
        need_config: true
      }, status: :unprocessable_entity
    end

    begin
      # 封面图：如果前端传了，就用前端传的封面URL，没有的话找正文中第一个图片，还没有就报错
      cover_url = params[:cover_image_url] || extract_first_image_url(@document.content)
      
      if cover_url.blank?
        return render json: { 
          success: false, 
          message: "同步失败：微信公众号草稿必须包含一张封面图，请在正文中添加至少一张图片。" 
        }, status: :unprocessable_entity
      end

      # 1. 临时补全图片可能需要的 host
      cover_url = URI.join(ENV.fetch('HOST_URL', "http://#{request.host_with_port}"), cover_url).to_s unless cover_url.start_with?('http')
      
      # 2. 上传永久封面素材获取 media_id
      thumb_media_id = sync_service.upload_material_image(cover_url)

      # 3. 将包含完整 HTML 图片替换逻辑的内容推到草稿箱
      draft_media_id = sync_service.push_draft(@document, thumb_media_id)
      
      render json: { success: true, message: "文章已成功同步至微信公众平台草稿箱！媒体ID: #{draft_media_id}" }
    rescue Wechat::SyncService::SyncError => e
      render json: { success: false, message: "同步失败：#{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Wechat Sync Unexpected Error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { success: false, message: "系统错误，请联系管理员或稍后重试。" }, status: :internal_server_error
    end
  end

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

  # 提取正文里的第一张图片的 src
  def extract_first_image_url(html_content)
    return nil if html_content.blank?
    doc = Nokogiri::HTML::DocumentFragment.parse(html_content)
    first_img = doc.css('img').first
    first_img ? first_img['src'] : nil
  end
end
