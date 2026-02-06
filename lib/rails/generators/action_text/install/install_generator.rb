# frozen_string_literal: true

# Override Rails' default action_text:install generator
# Redirects to our custom ActionTextGenerator
module ActionText
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Install ActionText with Tailwind CSS and TypeScript support"

      def redirect_to_custom_generator
        say "Redirecting to custom ActionText generator...", :blue
        generate "action_text"
      end
    end
  end
end

