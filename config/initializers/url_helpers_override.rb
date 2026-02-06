# frozen_string_literal: true

# Override rails_blob_url to ignore host parameter when default_url_options[:host] is configured
# This prevents AI-generated code from hardcoding localhost:3000
module UrlHelpersOverride
  def rails_blob_url(blob, **options)
    # If default host is configured, remove any host parameter
    # to use the configured default instead
    if Rails.application.routes.default_url_options[:host].present?
      options.delete(:host)
      options.delete(:port)
      options.delete(:protocol)
    end

    super(blob, **options)
  end
end

Rails.application.config.to_prepare do
  Rails.application.routes.url_helpers.singleton_class.prepend(UrlHelpersOverride)
end
