require 'ostruct'

class Api::V1::ArticlesController < Api::V1::TokenBaseController
  # POST /api/v1/articles/push_to_wechat
  #
  # Headers:
  #   Authorization: Bearer wemd_xxxxxxxxxxxxxxxx
  #
  # Body (JSON):
  #   title:            String, 必填
  #   markdown:         String, 必填（正文 Markdown，可含 # 一级标题，会被自动剥除）
  #   cover_image_url:  String, 可选；不传则取正文第一张图
  #   color_scheme_id:  String, 可选；如 "claude_clay"，匹配 ThemeStyleMaps::COLOR_SCHEMES
  #   author:           String, 可选；默认用 user.name
  #   theme_id:         Integer, 可选；不传用用户默认或第一个内置主题
  def push_to_wechat
    title    = params[:title].to_s.strip
    markdown = params[:markdown].to_s
    return render_error(:invalid_params, '缺少 title') if title.blank?
    return render_error(:invalid_params, '缺少 markdown') if markdown.blank?

    sync_service = Wechat::SyncService.new(current_user)
    unless sync_service.ready?
      return render_error(:wechat_not_configured,
                          '当前账号未配置微信公众号 AppID/AppSecret，请前往「账号设置 → 微信公众号配置」填写')
    end

    # 1. 临时应用 color_scheme（不持久化，仅本次请求生效）
    apply_color_scheme!(params[:color_scheme_id]) if params[:color_scheme_id].present?

    # 2. 选 theme（不传时走兜底）
    theme = resolve_theme(params[:theme_id])

    # 3. 决定 author（默认覆盖 user.name 给 SyncService 用）
    if params[:author].present?
      author_name = params[:author].to_s
      current_user.define_singleton_method(:name) { author_name }
    end

    # 4. 决定封面 URL
    cover_url = params[:cover_image_url].presence || extract_first_image(markdown)
    if cover_url.blank?
      return render_error(:missing_cover, '微信草稿必须有封面图：请传 cover_image_url，或在 markdown 正文中加一张图')
    end

    # 5. 构造伪文档（与 wechat_preview 同款 Struct 玩法），喂给 SyncService
    pseudo_doc = OpenStruct.new(content: markdown, theme: theme, title: title)

    begin
      thumb_media_id = sync_service.upload_material_image(cover_url)
      draft_media_id = sync_service.push_draft(pseudo_doc, thumb_media_id)

      # 6. 推送成功后，在红中文章库存一份（API 路径同步可见到 Web 文章目录）
      document = current_user.documents.build(
        title: title,
        content: markdown,
        theme: theme,
        is_auto_save: false
      )
      saved_to_library = document.save
      Document.cleanup_old_entries(current_user) if saved_to_library

      render json: {
        ok: true,
        draft_media_id: draft_media_id,
        wechat_draft_url: 'https://mp.weixin.qq.com/cgi-bin/appmsg?action=list&type=77',
        document_id: saved_to_library ? document.friendly_id : nil,
        document_url: saved_to_library ? edit_document_url(document) : nil,
        message: '已推送到微信公众号草稿箱，请前往后台预览/发布'
      }
    rescue Wechat::SyncService::SyncError => e
      render_error(:wechat_api_error, e.message, status: :unprocessable_entity)
    rescue => e
      Rails.logger.error("[API push_to_wechat] #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
      render_error(:internal_error, "系统错误：#{e.class}: #{e.message}", status: :internal_server_error)
    end
  end

  private

  def apply_color_scheme!(scheme_id)
    require Rails.root.join('app/services/wechat/theme_style_maps')
    scheme = Wechat::ThemeStyleMaps.scheme_by_id(scheme_id)
    return unless scheme

    # 仅在内存中改，不写库
    current_user.wx_primary_color = scheme[:primary]
    current_user.wx_bold_color = scheme[:bold]
  end

  def resolve_theme(theme_id)
    if theme_id.present?
      t = Theme.find_by(id: theme_id)
      return t if t
    end
    # 兜底：用一个微信适配过的内置主题
    Theme.where(name: ['李笑来原版']).first || Theme.first
  end

  # 从 markdown 提取第一张图 URL（兼容 ![](url) 与 <img src="url">）
  def extract_first_image(markdown)
    md = markdown.to_s
    if (m = md.match(/!\[[^\]]*\]\((https?:\/\/[^\s)]+)\)/))
      return m[1]
    end
    if (m = md.match(/<img[^>]+src=["'](https?:\/\/[^"']+)["']/i))
      return m[1]
    end
    nil
  end

  def render_error(code, message, status: :unprocessable_entity)
    render json: { ok: false, error: code.to_s, message: message }, status: status
  end
end
