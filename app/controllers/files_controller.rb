class FilesController < ApplicationController
  # GET /f/:short_code
  def show
    # Extract short code from params (without extension)
    short_code = params[:id].to_s.split('.').first
    
    blob = ActiveStorage::Blob.find_by!(short_code: short_code)
    
    # 直接重定向到存储服务的 URL（七牛云 CDN）
    # 这样可以充分利用 CDN 加速，减少服务器带宽和负载
    redirect_to blob.url, allow_other_host: true
  end
end
