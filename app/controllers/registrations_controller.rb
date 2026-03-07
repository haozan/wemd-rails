class RegistrationsController < ApplicationController
  before_action :redirect_if_signed_in, only: [:new, :create, :verify, :confirm]
  before_action :check_session_cookie_availability, only: [:new]

  # 第一步：显示注册表单
  def new
    @user = User.new
  end

  # 第一步提交：创建用户（verified: false），发验证码，跳转验证码页
  def create
    @user = User.new(user_params)
    @user.verified = false

    if @user.save
      code = @user.generate_email_verification_code!
      UserMailer.with(user: @user, code: code).email_verification_code.deliver_later
      session[:pending_user_id] = @user.id  # 临时存 session，供第二步使用
      redirect_to verify_sign_up_path, notice: "验证码已发送到 #{@user.email}，请在 15 分钟内完成验证"
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :new, status: :unprocessable_entity
    end
  end

  # 第二步：显示验证码输入页
  def verify
    @pending_user = User.find_by(id: session[:pending_user_id])
    redirect_to sign_up_path, alert: "请先完成注册" unless @pending_user
  end

  # 第二步提交：校验验证码，成功则登录
  def confirm
    @pending_user = User.find_by(id: session[:pending_user_id])

    unless @pending_user
      redirect_to sign_up_path, alert: "请先完成注册" and return
    end

    if @pending_user.verify_email_code!(params[:code])
      session.delete(:pending_user_id)
      session_record = @pending_user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }
      redirect_to root_path, notice: "欢迎！注册成功，邮箱已验证 🎉"
    else
      flash.now[:alert] = "验证码错误或已过期，请重新输入"
      render :verify, status: :unprocessable_entity
    end
  end

  # 重新发送验证码
  def resend_code
    @pending_user = User.find_by(id: session[:pending_user_id])

    unless @pending_user
      redirect_to sign_up_path, alert: "请先完成注册" and return
    end

    code = @pending_user.generate_email_verification_code!
    UserMailer.with(user: @pending_user, code: code).email_verification_code.deliver_later
    redirect_to verify_sign_up_path, notice: "验证码已重新发送到 #{@pending_user.email}，请查收"
  end

  private

  def redirect_if_signed_in
    redirect_to root_path, notice: "您已登录" if user_signed_in?
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
