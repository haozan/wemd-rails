module AuthenticationHelpers
  def sign_in_as(user)
    # Create session directly without password - works with seed data
    # Use api_sign_in_as for request specs (uses Authorization header)
    api_sign_in_as(user)
  end

  # API authentication - sets Authorization header with session token
  def api_sign_in_as(user)
    session = user.sessions.create!
    @api_session = session
    @api_auth_headers = { 'Authorization' => "Bearer #{session.id}" }
  end

  # Get API auth headers (for use in API request specs)
  def api_auth_headers
    @api_auth_headers || {}
  end

  def sign_in_system(user)
    # For system tests - finds submit button regardless of text/translation
    visit sign_in_path
    fill_in 'user[email]', with: user.email
    fill_in 'user[password]', with: user.password
    find('button[type="submit"]').click
  end

  def current_user
    return nil unless cookies.signed[:session_token]

    session = Session.find_by(id: cookies.signed[:session_token])
    session&.user
  end

  def sign_out
    delete sign_out_path
  end

end

module ApiRequestHelpers
  # Override RSpec request methods to automatically include API auth headers
  %i[get post put patch delete].each do |method|
    define_method(method) do |path, **args|
      # Merge api_auth_headers if they exist
      if respond_to?(:api_auth_headers) && api_auth_headers.present?
        args[:headers] = (args[:headers] || {}).merge(api_auth_headers)
      end
      super(path, **args)
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :feature
  config.include AuthenticationHelpers, type: :system

  # Auto-inject API auth headers in request specs
  config.include ApiRequestHelpers, type: :request
end
