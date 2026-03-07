class Identity::EmailsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to_root
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    # OAuth 用户没有密码，允许不填 password_challenge
    # 普通用户修改邮箱需要验证当前密码
    if current_user.oauth_user?
      params.require(:user).permit(:email).with_defaults(password_challenge: "")
    else
      params.require(:user).permit(:email, :password_challenge)
    end
  end

  def redirect_to_root
    if @user.email_previously_changed?
      resend_email_verification
      redirect_to root_path, notice: "邮箱已更新，验证邮件已发送，请查收并点击验证链接"
    else
      redirect_to root_path
    end
  end

  def resend_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
