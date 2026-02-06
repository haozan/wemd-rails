# Configure default behavior for skip_before_action to use raise: false
# This prevents exceptions when trying to skip non-existent before_actions

Rails.application.config.to_prepare do
  # Patch method to add skip_action overrides
  def patch_skip_actions(controller_class)
    return if controller_class.respond_to?(:original_skip_before_action)

    controller_class.class_eval do
      class << self
        # Store original methods
        alias_method :original_skip_before_action, :skip_before_action
        alias_method :original_skip_after_action, :skip_after_action
        alias_method :original_skip_around_action, :skip_around_action

        # Override skip_before_action to default raise: false
        def skip_before_action(*names, **options)
          # Set raise: false as default if not explicitly specified
          options[:raise] = false unless options.key?(:raise)
          original_skip_before_action(*names, **options)
        end

        # Also override other skip_action methods for consistency
        def skip_after_action(*names, **options)
          options[:raise] = false unless options.key?(:raise)
          original_skip_after_action(*names, **options)
        end

        def skip_around_action(*names, **options)
          options[:raise] = false unless options.key?(:raise)
          original_skip_around_action(*names, **options)
        end
      end
    end
  end

  # Apply patches to both ActionController::Base and ActionController::API
  patch_skip_actions(ActionController::Base)
  patch_skip_actions(ActionController::API)
end