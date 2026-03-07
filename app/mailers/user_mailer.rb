class UserMailer < ApplicationMailer
  # 密码重置邮件（链接方式，20分钟有效）
  def password_reset
    @user = params[:user]
    @signed_id = @user.generate_token_for(:password_reset)

    mail to: @user.email, subject: "【#{Rails.application.config.x.appname}】重置您的密码"
  end

  # 邮箱验证邮件（链接方式，用于修改邮箱后验证，2天有效）
  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    mail to: @user.email, subject: "【#{Rails.application.config.x.appname}】验证您的邮箱"
  end

  # 邮箱验证码（6位数字，注册/登录时使用，15分钟有效）
  def email_verification_code
    @user = params[:user]
    @code = params[:code]

    # 开发环境无 SMTP 时，验证码会通过 User#generate_email_verification_code! 打印到日志
    mail to: @user.email,
         subject: "【#{Rails.application.config.x.appname}】您的验证码：#{@code}"
  end

  # 邀请注册邮件
  def invitation_instructions
    @user = params[:user]
    @signed_id = @user.generate_token_for(:password_reset)

    mail to: @user.email, subject: "【#{Rails.application.config.x.appname}】邀请您加入"
  end
end
