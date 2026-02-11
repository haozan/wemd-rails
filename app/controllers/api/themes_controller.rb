class Api::ThemesController < Api::BaseController
  skip_before_action :authenticate_user_from_token!
  
  # GET /api/themes/:id/css
  def css
    theme = Theme.find(params[:id])
    
    render json: { 
      id: theme.id, 
      name: theme.name, 
      css: theme.css 
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Theme not found' }, status: :not_found
  end
end
