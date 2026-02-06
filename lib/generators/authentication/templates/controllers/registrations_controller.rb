class RegistrationsController < ApplicationController
  before_action :redirect_if_signed_in, only: [:new, :create]
  before_action :check_session_cookie_availability, only: [:new]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      send_email_verification
      redirect_to root_path, notice: "Welcome! You have signed up successfully"
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_signed_in
    redirect_to root_path, notice: "You are already signed in" if user_signed_in?
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def send_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
