class Identity::EmailVerificationsController < ApplicationController
  before_action :authenticate_user!, only: :create

  before_action :set_user, only: :show

  # 点击邮件链接验证（链接方式，用于修改邮箱后重新验证）
  def show
    @user.update! verified: true
    redirect_to profile_path, notice: "邮箱验证成功！"
  end

  # 重新发送验证邮件（需已登录）
  def create
    if current_user.email_was_generated?
      redirect_to profile_path, alert: "您的邮箱是系统自动生成的，无法验证。请先在个人资料页更新为真实邮箱。"
      return
    end
    send_email_verification
    redirect_to profile_path, notice: "验证邮件已发送到您的邮箱，请查收并点击验证链接"
  end

  private

  def set_user
    @user = User.find_by_token_for!(:email_verification, params[:sid])
  rescue StandardError
    redirect_to edit_identity_email_path, alert: "邮箱验证链接无效或已过期，请重新发送"
  end

  def send_email_verification
    UserMailer.with(user: Current.user).email_verification.deliver_later
  end
end
