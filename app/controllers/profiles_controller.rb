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

  private

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
