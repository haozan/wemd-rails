class Identity::PasswordResetsController < ApplicationController
  before_action :set_user, only: %i[ edit update ]

  def new
    @user = User.new
  end

  def edit
  end

  def create
    if @user = User.find_by(email: params[:user][:email], verified: true)
      send_password_reset_email
      redirect_to sign_in_path, notice: "请检查邮箱获取重置说明"
    else
      redirect_to new_identity_password_reset_path, alert: "验证邮箱后才能重置密码"
    end
  end

  def update
    if @user.update(user_params)
      redirect_to sign_in_path, notice: "密码重置成功，请登录"
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by_token_for!(:password_reset, params[:sid])
  rescue StandardError
    redirect_to new_identity_password_reset_path, alert: "密码重置链接无效"
  end

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def send_password_reset_email
    UserMailer.with(user: @user).password_reset.deliver_later
  end
end
