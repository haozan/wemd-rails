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

  # AJAX: 快速保存文章主色（编辑器工具栏用）
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
