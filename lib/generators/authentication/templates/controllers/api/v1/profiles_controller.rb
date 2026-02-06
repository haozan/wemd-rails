class Api::V1::ProfilesController < Api::BaseController
  before_action :authenticate_user!

  # GET /api/v1/profile
  def show
    render json: {
      user: {
        id: current_user.id,
        name: current_user.name,
        email: current_user.email
      }
    }, status: :ok
  end

  # PUT /api/v1/profile
  def update
    if current_user.update(user_params)
      render json: {
        user: {
          id: current_user.id,
          name: current_user.name,
          email: current_user.email
        },
        message: "Profile updated successfully"
      }, status: :ok
    else
      render json: {
        error: current_user.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/password
  def update_password
    unless current_user.authenticate(params[:current_password])
      render json: {
        error: "Current password is incorrect"
      }, status: :unprocessable_entity
      return
    end

    if current_user.update(password_params)
      render json: {
        message: "Password updated successfully"
      }, status: :ok
    else
      render json: {
        error: current_user.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(:name, :email)
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
