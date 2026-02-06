# Set EnhancedFormBuilder as the default form builder for the application
# This ensures all form_with and form_for calls automatically use our enhanced builder
# unless explicitly overridden with builder: option

Rails.application.config.to_prepare do
  ActionView::Base.default_form_builder = EnhancedFormBuilder

  # Disable HTML5 native form validation globally
  # We handle validation on the backend with Rails validators
  module FormWithNoValidate
    def form_with(**options, &block)
      options[:html] ||= {}
      options[:html][:novalidate] = true unless options[:html].key?(:novalidate)
      super
    end
  end

  ActionView::Helpers::FormHelper.prepend(FormWithNoValidate)
end
