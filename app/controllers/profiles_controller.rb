class ProfilesController < ApplicationController
  before_action :authenticate

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(user_params)
      need_email_verification = @user.previous_changes.include?(:email)
      if need_email_verification
        send_email_verification
        additional_notice = "，并已发送验证邮件到您的新邮箱"
      end
      redirect_to profile_path, notice: "个人资料已更新#{additional_notice}"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit_password
    @user = current_user
  end

  def update_password
    @user = current_user

    unless @user.authenticate(params[:user][:current_password])
      flash.now[:alert] = "当前密码不正确"
      render :edit_password, status: :unprocessable_entity
      return
    end

    if @user.update(password_params)
      redirect_to profile_path, notice: "密码已更新"
    else
      render :edit_password, status: :unprocessable_entity
    end
  end

  def wechat_settings
    @user = current_user
  end

  def update_wechat_settings
    @user = current_user
    
    if @user.update(wechat_settings_params)
      redirect_to wechat_settings_profile_path, notice: "微信配置已保存"
    else
      render :wechat_settings, status: :unprocessable_entity
    end
  end

  def test_wechat_connection
    app_id     = params[:app_id].to_s.strip
    app_secret = params[:app_secret].to_s.strip

    # 如果 app_secret 留空，尝试用已保存的
    if app_secret.blank?
      app_secret = current_user.wechat_app_secret.to_s
    end

    if app_id.blank? || app_secret.blank?
      render json: { ok: false, message: "AppID 和 AppSecret 不能为空" } and return
    end

    # 直接调微信接口，不经过缓存，确保每次都测最新配置
    begin
      url = URI("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{app_id}&secret=#{app_secret}")
      response = Net::HTTP.get_response(url)
      result   = JSON.parse(response.body)

      if result["access_token"].present?
        render json: { ok: true, message: "✅ 连接成功！配置正确。" }
      else
        errmsg = result["errmsg"] || "未知错误"
        render json: { ok: false, message: "❌ 连接失败：#{errmsg}（请检查 AppID/AppSecret 是否正确，以及服务器 IP 是否已加入白名单）" }
      end
    rescue => e
      render json: { ok: false, message: "请求失败：#{e.message}" }
    end
  end


  def update_primary_color
    @user = current_user
    color = params[:wx_primary_color].to_s.strip

    if @user.update(wx_primary_color: color.presence)
      render json: { ok: true, wx_primary_color: @user.wx_primary_color }
    else
      render json: { ok: false, error: @user.errors[:wx_primary_color].first || "颜色格式错误" }, status: :unprocessable_entity
    end
  end

  # AJAX: 同时更新主色 + 加粗色(配色方案选择器专用)
  def update_color_scheme
    @user = current_user
    primary = params[:primary_color].to_s.strip
    bold    = params[:bold_color].to_s.strip

    if @user.update(wx_primary_color: primary.presence, wx_bold_color: bold.presence)
      render json: {
        ok: true,
        primary_color: @user.wx_primary_color,
        bold_color: @user.wx_bold_color
      }
    else
      render json: {
        ok: false,
        error: (@user.errors.full_messages.first || "颜色格式错误")
      }, status: :unprocessable_entity
    end
  end

  # ============== API Token 管理（供外部 skill 调用红中 API） ==============

  def api_tokens
    @user = current_user
    @api_tokens = @user.api_tokens.order(created_at: :desc)
    # 通过 flash 传递新生成的明文 token（只显示一次）
    @plain_token = flash[:plain_token]
    @plain_token_id = flash[:plain_token_id]
  end

  def create_api_token
    name = params[:name].to_s.strip.presence || 'Untitled token'
    record, plain = ApiToken.issue!(current_user, name: name)

    flash[:plain_token] = plain
    flash[:plain_token_id] = record.id
    flash[:notice] = '✅ Token 已生成，请立即复制保存（关闭页面后不再显示）'
    redirect_to api_tokens_profile_path
  rescue => e
    flash[:alert] = "Token 创建失败：#{e.message}"
    redirect_to api_tokens_profile_path
  end

  def destroy_api_token
    token = current_user.api_tokens.find_by(id: params[:id])
    if token
      token.destroy
      flash[:notice] = '🗑 Token 已删除'
    else
      flash[:alert] = 'Token 不存在'
    end
    redirect_to api_tokens_profile_path
  end

  private

  def wechat_settings_params
    params.require(:user).permit(:wechat_app_id, :wechat_app_secret, :wx_primary_color)
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def send_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
