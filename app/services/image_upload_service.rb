class ImageUploadService < ApplicationService
  # 图片上传服务
  # 使用 ActiveStorage 存储图片，返回图片 URL
  
  def initialize(file, user)
    @file = file
    @user = user
  end

  def call
    # 验证文件
    validate_file!
    
    # 创建临时 Document 用于存储图片
    # 或直接使用 ActiveStorage::Blob
    blob = ActiveStorage::Blob.create_and_upload!(
      io: @file.tempfile,
      filename: sanitize_filename(@file.original_filename),
      content_type: @file.content_type
    )
    
    # 返回图片 URL
    # ActiveStorage 会自动上传到配置的存储位置
    {
      success: true,
      url: rails_blob_url(blob),
      filename: blob.filename.to_s,
      size: blob.byte_size
    }
  rescue StandardError => e
    {
      success: false,
      error: e.message
    }
  end

  private

  def validate_file!
    raise "文件不能为空" unless @file.present?
    raise "文件类型不支持" unless valid_content_type?
    raise "文件大小超过限制 (10MB)" if @file.size > 10.megabytes
  end

  def valid_content_type?
    %w[image/jpeg image/png image/gif image/webp image/svg+xml].include?(@file.content_type)
  end

  def sanitize_filename(filename)
    # 移除特殊字符，保留扩展名
    extension = File.extname(filename)
    basename = File.basename(filename, extension)
    sanitized = basename.gsub(/[^0-9A-Za-z.\-_]/, '_')
    timestamp = Time.current.to_i
    "#{timestamp}_#{sanitized}#{extension}"
  end

  def rails_blob_url(blob)
    # 使用 Rails URL helpers 生成 blob URL
    Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV['PUBLIC_HOST'] || 'localhost:3000')
  end
end
