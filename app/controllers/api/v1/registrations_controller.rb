class Api::V1::RegistrationsController < Api::BaseController
  # API sign up endpoint
  def create
    @user = User.new(user_params)

    if @user.save
      @session = @user.sessions.create!

      render json: {
        user: {
          id: @user.id,
          name: @user.name,
          email: @user.email
        },
        session_token: @session.id,
        message: "Signed up successfully"
      }, status: :created
    else
      render json: {
        error: @user.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
