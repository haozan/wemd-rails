# frozen_string_literal: true

module EnvChecker
  class << self
    # Get application port with smart detection
    # Priority: ENV['APP_PORT'] > ENV['PORT'] > application.yml > auto-detect (3001 for submodule, 3000 for standalone)
    def get_app_port
      # 1. Check environment variables first
      return ENV['APP_PORT'] if ENV['APP_PORT'] && !ENV['APP_PORT'].empty?
      return ENV['PORT'] if ENV['PORT'] && !ENV['PORT'].empty?

      # 2. Read from application.yml if exists
      if File.exist?('config/application.yml')
        require 'yaml'
        begin
          config = YAML.load_file('config/application.yml')
          app_port = config['APP_PORT']
          if app_port && !app_port.to_s.strip.empty?
            return app_port.to_s.gsub(/['"]/, '')
          end
        rescue => e
          # Ignore YAML parsing errors, fall through to auto-detect
        end
      end

      # 3. Auto-detect based on whether running as submodule
      if is_submodule?
        '3001'  # Submodule: parent app uses 3000, backend uses 3001
      else
        '3000'  # Standalone: use default Rails port
      end
    end

    # Check if current directory is a git submodule
    # by looking for .gitmodules in parent directory
    def is_submodule?
      parent_dir = File.expand_path('..')
      File.exist?(File.join(parent_dir, '.gitmodules'))
    end

    # Get environment variable value, return default value if not exists
    def get_env_var(var_name, default: nil, must: false)
      default ||= ''
      env_var = ENV.fetch(var_name, default)
      env_var = default if env_var.blank?

      if must && env_var.nil?
        raise "get_env_var error, missing key: #{var_name}"
      end

      env_var
    end

    def get_public_host_and_port_and_protocol
      # Use centralized port detection
      local_port = get_app_port

      if ENV['PUBLIC_HOST'].present?
        return { host: ENV.fetch('PUBLIC_HOST'), port: 443, protocol: 'https' }
      end

      # If CLACKY_PUBLIC_HOST is blank and CLACKY_PREVIEW_DOMAIN_BASE is present,
      # use APP_PORT (or PORT, default 3000) + CLACKY_PREVIEW_DOMAIN_BASE
      if ENV['CLACKY_PREVIEW_DOMAIN_BASE'].present?
        domain_base = ENV.fetch('CLACKY_PREVIEW_DOMAIN_BASE')
        return { host: "#{local_port}#{domain_base}", port: 443, protocol: 'https' }
      end

      # Rails.logger is not ready here, use puts instead.
      # puts "EnvChecker: public host fallback to localhost: #{local_port}..."
      return { host: 'localhost', port: local_port, protocol: 'http' }
    end

    # Load environment variable names from application.yml.example
    # Returns an array of hashes: [{ name: 'VAR_NAME', optional: true/false }, ...]
    def load_example_env_vars(example_file = 'config/application.yml.example')
      return [] unless File.exist?(example_file)

      lines = File.readlines(example_file)
      env_var_configs = lines
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?('#') }
        .map do |line|
          parts = line.split(':', 2)
          next nil if parts.size != 2

          var_name = parts[0].strip
          var_value = parts[1].strip

          # Check if value uses ERB template with ENV.fetch or Env.fetch
          # Pattern: <%= ENV.fetch('CLACKY_xxx') %> or <%= Env.fetch('CLACKY_xxx') %>
          optional = var_value.match?(/<%=\s*(?:ENV|Env)\.fetch\(['"]CLACKY_/)

          { name: var_name, optional: optional }
        end
        .compact

      env_var_configs.uniq { |config| config[:name] }
    end

    # Check if all required environment variables exist and have values
    # Variables are considered optional if:
    # 1. They end with '_OPTIONAL' suffix
    # 2. Their value in application.yml.example uses <%= ENV.fetch('CLACKY_xxx') %>
    def check_required_env_vars(example_env_configs = nil)
      if get_env_var('SECRET_KEY_BASE_DUMMY').present?
        puts 'SECRET_KEY_BASE_DUMMY is setted, skip check_required_env_vars...'
        return
      end

      example_env_configs ||= load_example_env_vars

      missing_vars = example_env_configs.reject do |config|
        var_name = config[:name]
        is_optional = config[:optional] || var_name.end_with?('_OPTIONAL')

        is_optional || get_env_var(var_name).present?
      end.map { |config| config[:name] }

      if missing_vars.any?
        raise "Config error, missing these env keys: #{missing_vars.join(', ')}"
      end
    end
  end
end
