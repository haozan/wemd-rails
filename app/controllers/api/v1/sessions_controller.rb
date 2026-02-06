class Api::V1::SessionsController < Api::BaseController
  # API login endpoint specifically for curl/API usage
  def login
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      @session = user.sessions.create!
      
      render json: {
        user: {
          id: user.id,
          name: user.name,
          email: user.email
        },
        session_token: @session.id,
        message: "Signed in successfully"
      }, status: :ok
    else
      render json: {
        error: "That email or password is incorrect"
      }, status: :unauthorized
    end
  end

  def destroy
    @session = Current.session
    if @session
      @session.destroy!
      render json: { message: "Signed out successfully" }, status: :ok
    else
      render json: { error: "No active session found" }, status: :unauthorized
    end
  end
end
