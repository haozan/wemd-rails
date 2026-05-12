class Api::V1::UploadsController < Api::V1::TokenBaseController
  # POST /api/v1/uploads
  #
  # multipart/form-data:
  #   file: 二进制图片文件 (jpeg/png/gif/webp/svg, ≤ 10MB)
  #
  # 响应:
  #   { ok: true, url: "https://...", filename: "...", size: 12345 }
  def create
    uploaded_file = params[:file]
    if uploaded_file.blank?
      return render json: { ok: false, error: 'missing_file', message: '缺少 file 字段' },
                    status: :unprocessable_entity
    end

    result = ImageUploadService.call(uploaded_file, current_user, request)

    if result[:success]
      render json: {
        ok: true,
        url: result[:url],
        filename: result[:filename],
        size: result[:size]
      }, status: :created
    else
      render json: { ok: false, error: 'upload_failed', message: result[:error] },
             status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("[API v1 uploads] #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    render json: { ok: false, error: 'internal_error', message: '图片上传失败，请稍后重试' },
           status: :internal_server_error
  end
end
