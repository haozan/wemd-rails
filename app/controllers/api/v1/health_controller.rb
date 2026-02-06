class Api::V1::HealthController < Api::BaseController
  def index
    render json: {
      status: 'ok',
      message: 'API is running',
      timestamp: Time.current.iso8601,
      version: '1.0.0'
    }
  end
end
