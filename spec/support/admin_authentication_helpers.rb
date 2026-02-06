module AdminAuthenticationHelpers
  def admin_sign_in_as(admin)
    post admin_login_path, params: {
      name: admin.name,
      password: admin.password
    }
  end
end

RSpec.configure do |config|
  config.include AdminAuthenticationHelpers, type: :request
  config.include AdminAuthenticationHelpers, type: :feature
end
