module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Try to authenticate via session token from cookies
      if session_token = cookies.signed[:session_token]
        if session_record = Session.find_by(id: session_token)
          return session_record.user
        end
      # Try to authenticate via Authorization header (for API clients)
      elsif auth_header = request.headers['Authorization']
        token = auth_header.gsub(/Bearer\s+/, '')
        if session_record = Session.find_by(id: token)
          return session_record.user
        end
      end

      # Allow unauthenticated connections (e.g., for Turbo::StreamsChannel)
      # Channels requiring authentication should check current_user in their subscribed method
      nil
    end
  end
end
