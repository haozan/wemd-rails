# Broadcast Rails logger errors to frontend via ActionCable (development only)
# Only broadcasts errors from app/ directory (business logic)
# Frontend error_handler will deduplicate automatically
#
# In test environment, raise exception when logger.error is called

if Rails.env.development? || Rails.env.test?
  Rails.application.config.after_initialize do
    class << Rails.logger
      alias_method :original_error, :error unless method_defined?(:original_error)

      # Support formats:
      # Rails.logger.error("message")                    - broadcasts in dev, raises in test
      # Rails.logger.error("message", broadcast: false)  - no broadcast in dev
      # Rails.logger.error(exception)                    - broadcasts in dev, raises in test
      # Rails.logger.error(exception, broadcast: false)  - no broadcast in dev
      # Rails.logger.error { "message" }                 - broadcasts in dev, raises in test
      def error(message = nil, broadcast: true, &block)
        result = original_error(message, &block)
        actual_message = message || block&.call

        unless broadcast && actual_message && from_app_directory?
          return result
        end

        if Rails.env.development?
          broadcast_to_frontend(actual_message)
        end

        if Rails.env.test?
          error_data = build_error_data(actual_message)
          exception = RuntimeError.new("Rails.logger.error called:\n#{error_data[:message]}")
          exception.set_backtrace(error_data[:backtrace])
          raise exception
        end

        result
      end

      private

      def from_app_directory?
        # Check if the DIRECT caller (not any line in stack) is from app/ directory
        # This prevents gem errors from being broadcasted even if they pass through app code
        cleaned = Rails.backtrace_cleaner.clean(caller)
        return false if cleaned.empty?

        # Check first non-broadcasting_logger line
        first_line = cleaned.find { |line| !line.include?('broadcasting_logger') }
        first_line&.start_with?('app/') || false
      end

      # Build error data structure
      def build_error_data(message)
        if message.is_a?(Exception)
          {
            message: "#{message.class}: #{message.message}",
            backtrace: format_backtrace(message.backtrace || []),
            timestamp: Time.current.iso8601,
            source: 'rails_logger',
            level: 'error'
          }
        else
          {
            message: filter_sensitive_data(message.to_s),
            backtrace: format_backtrace(caller),
            timestamp: Time.current.iso8601,
            source: 'rails_logger',
            level: 'error'
          }
        end
      end

      # Format and filter backtrace to show only relevant business logic
      def format_backtrace(backtrace)
        # Clean with Rails backtrace cleaner
        cleaned = Rails.backtrace_cleaner.clean(backtrace)

        # Filter out calls from this file (broadcasting_logger.rb)
        filtered = cleaned.reject { |line| line.include?('broadcasting_logger') }

        # Take first 10 lines
        filtered.first(10).join("\n")
      end

      def broadcast_to_frontend(message)
        error_data = build_error_data(message)

        # Broadcast to frontend
        Turbo::StreamsChannel.broadcast_render_to(
          "system_monitor",
          inline: "<turbo-stream action='report_logger_error' data-error='<%= error_data.to_json.gsub(\"'\", \"&#39;\") %>'></turbo-stream>",
          locals: { error_data: error_data }
        )
      rescue => e
        original_error("Failed to broadcast: #{e.message}")
      end

      def filter_sensitive_data(message)
        message.gsub(/password[=:]\s*\S+/i, 'password=***')
               .gsub(/token[=:]\s*\S+/i, 'token=***')
               .gsub(/secret[=:]\s*\S+/i, 'secret=***')
      end
    end
  end
end
