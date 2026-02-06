class Api::UploadsController < Api::BaseController
  before_action :authenticate_user!

  # POST /api/uploads
  def create
    uploaded_file = params[:file]
    
    if uploaded_file.blank?
      render json: { success: false, error: '请选择要上传的图片' }, status: :unprocessable_entity
      return
    end

    result = QiniuUploadService.call(uploaded_file, Current.user)
    
    if result[:success]
      render json: result, status: :created
    else
      render json: result, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "图片上传失败: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, error: '图片上传失败，请重试' }, status: :internal_server_error
  end
end
