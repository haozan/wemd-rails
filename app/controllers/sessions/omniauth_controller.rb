class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def create
    @user = User.from_omniauth(omniauth)

    if @user.persisted?
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      redirect_to root_path, notice: "Successfully signed in with #{omniauth.provider.humanize}"
    else
      flash[:alert] = handle_password_errors(@user)
      redirect_to sign_in_path
    end
  end

  def failure
    error_type = params[:message] || request.env['omniauth.error.type']

    error_message = case error_type.to_s
    when 'access_denied'
      "Authorization was cancelled. Please try again if you'd like to sign in."
    when 'invalid_credentials'
      "Invalid credentials provided. Please check your information and try again."
    when 'timeout'
      "Authentication timed out. Please try again."
    else
      "Authentication failed: #{error_type&.to_s&.humanize || 'Unknown error'}"
    end

    flash[:alert] = error_message
    redirect_to sign_in_path
  end

  private

  def omniauth
    request.env["omniauth.auth"]
  end
end
