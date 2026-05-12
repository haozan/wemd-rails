class Api::V1::TokenBaseController < ActionController::API
  include ActionController::Cookies

  before_action :authenticate_with_api_token!

  attr_reader :current_user, :current_api_token

  private

  def authenticate_with_api_token!
    header = request.headers['Authorization'].to_s
    plain = header.sub(/\ABearer\s+/, '').strip

    if plain.blank?
      return render json: { ok: false, error: 'missing_token', message: '缺少 Authorization: Bearer <token> 头' },
                    status: :unauthorized
    end

    token_record = ApiToken.authenticate(plain)
    if token_record.nil?
      return render json: { ok: false, error: 'invalid_token', message: 'Token 无效或已被撤销' },
                    status: :unauthorized
    end

    @current_api_token = token_record
    @current_user = token_record.user
    token_record.touch_usage!(ip: request.ip)
  end
end
