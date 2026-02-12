class FilesController < ApplicationController
  # GET /f/:short_code
  def show
    # Extract short code from params (without extension)
    short_code = params[:id].to_s.split('.').first
    
    blob = ActiveStorage::Blob.find_by!(short_code: short_code)
    
    # 直接提供文件内容，而非重定向
    # 这样可以避免测试环境中的跨域问题
    send_data blob.download, 
              type: blob.content_type, 
              disposition: 'inline',
              filename: blob.filename.to_s
  end
end
