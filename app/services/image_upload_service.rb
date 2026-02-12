class ImageUploadService < ApplicationService
  # 图片上传服务
  # 使用 ActiveStorage 存储图片，返回图片 URL
  
  def initialize(file, user, request = nil)
    @file = file
    @user = user
    @request = request
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
      url: short_url_for(blob),
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

  def short_url_for(blob)
    # 构建完整URL，支持复制到公众号等外部平台
    if @request.present?
      # 从请求中获取域名
      protocol = @request.protocol # 'http://' 或 'https://'
      host = @request.host_with_port # 包含端口的域名
      "#{protocol}#{host}#{blob.short_url}"
    else
      # 降级使用相对路径
      blob.short_url
    end
  end
end
