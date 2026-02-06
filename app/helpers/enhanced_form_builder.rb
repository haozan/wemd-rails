# Enhanced FormBuilder that automatically applies design system classes and controllers
# This helps AI and developers use standard Rails form helpers without worrying about
# CSS classes or Stimulus controllers for Tom Select, Flatpickr, etc.
class EnhancedFormBuilder < ActionView::Helpers::FormBuilder
  # Text input - automatically gets form-input class
  def text_field(method, options = {})
    add_default_class!(options, 'form-input')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # Number input - automatically gets form-input class
  def number_field(method, options = {})
    add_default_class!(options, 'form-input')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # Email input - automatically gets form-input class
  def email_field(method, options = {})
    add_default_class!(options, 'form-input')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # Password input - automatically gets form-input class
  def password_field(method, options = {})
    add_default_class!(options, 'form-input')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # URL input - automatically gets form-input class
  def url_field(method, options = {})
    add_default_class!(options, 'form-input')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # Telephone input - automatically gets form-input class
  def telephone_field(method, options = {})
    add_default_class!(options, 'form-input')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end
  alias_method :phone_field, :telephone_field

  # Text area - automatically gets form-textarea class
  def text_area(method, options = {})
    add_default_class!(options, 'form-textarea')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # Select - automatically gets Tom Select controller
  # Pass enhanced: false to skip Tom Select and use plain select with form-select class
  def select(method, choices = nil, options = {}, html_options = {}, &block)
    # Check if Tom Select should be disabled
    unless html_options.delete(:enhanced) == false
      # Tom Select enabled - add form-select class (will be copied to wrapper)
      add_default_class!(html_options, 'form-select')
      add_stimulus_controller!(html_options, 'tom-select')

      # Add placeholder data attribute if not present
      html_options[:data] ||= {}
      html_options[:data][:'tom_select_placeholder_value'] ||= "Select #{method.to_s.humanize.downcase}..."
    else
      # Plain select without Tom Select - add form-select class
      add_default_class!(html_options, 'form-select')
    end

    add_error_class!(html_options, method)
    field_with_errors(method) { super }
  end

  # Collection select - same enhancement as select
  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    unless html_options.delete(:enhanced) == false
      # Tom Select enabled - add form-select class (will be copied to wrapper)
      add_default_class!(html_options, 'form-select')
      add_stimulus_controller!(html_options, 'tom-select')

      html_options[:data] ||= {}
      html_options[:data][:'tom_select_placeholder_value'] ||= "Select #{method.to_s.humanize.downcase}..."
    else
      # Plain select without Tom Select - add form-select class
      add_default_class!(html_options, 'form-select')
    end

    add_error_class!(html_options, method)
    field_with_errors(method) { super }
  end

  # File field - automatically gets form-file class
  def file_field(method, options = {})
    add_default_class!(options, 'form-file')
    add_error_class!(options, method)
    field_with_errors(method) { super }
  end

  # Date field - automatically gets form-input and Flatpickr controller
  # Pass enhanced: false to skip Flatpickr
  def date_field(method, options = {})
    unless options.delete(:enhanced) == false
      add_default_class!(options, 'form-input')
      add_stimulus_controller!(options, 'flatpickr')

      options[:data] ||= {}
      options[:data][:'flatpickr_date_format_value'] ||= 'Y-m-d'

      # Convert value to string format if it's a Date/Time object
      if options[:value].respond_to?(:strftime)
        options[:value] = options[:value].strftime('%Y-%m-%d')
      end
    else
      add_default_class!(options, 'form-input')
    end

    super(method, options)
  end

  # Datetime field - automatically gets form-input and Flatpickr controller with time
  # Pass enhanced: false to skip Flatpickr
  def datetime_field(method, options = {})
    unless options.delete(:enhanced) == false
      add_default_class!(options, 'form-input')
      add_stimulus_controller!(options, 'flatpickr')

      options[:data] ||= {}
      options[:data][:'flatpickr_enable_time_value'] = true
      options[:data][:'flatpickr_date_format_value'] ||= 'Y-m-d H:i'

      # Convert value to string format if it's a Date/Time object
      if options[:value].respond_to?(:strftime)
        options[:value] = options[:value].strftime('%Y-%m-%d %H:%M')
      elsif @object && @object.respond_to?(method)
        value = @object.send(method)
        options[:value] = value.strftime('%Y-%m-%d %H:%M') if value.respond_to?(:strftime)
      end

      # Use text_field instead of datetime_field for Flatpickr
      return @template.content_tag(:div) do
        text_field(method, options)
      end
    else
      add_default_class!(options, 'form-input')
    end

    super(method, options)
  end

  # Time field - automatically gets form-input and Flatpickr controller (time only)
  # Pass enhanced: false to skip Flatpickr
  def time_field(method, options = {})
    unless options.delete(:enhanced) == false
      add_default_class!(options, 'form-input')
      add_stimulus_controller!(options, 'flatpickr')

      options[:data] ||= {}
      options[:data][:'flatpickr_enable_time_value'] = true
      options[:data][:'flatpickr_no_calendar_value'] = true
      options[:data][:'flatpickr_date_format_value'] ||= 'H:i'

      # Convert value to string format if it's a Time object
      if options[:value].respond_to?(:strftime)
        options[:value] = options[:value].strftime('%H:%M')
      end
    else
      add_default_class!(options, 'form-input')
    end

    super(method, options)
  end

  # Checkbox - keep default styling
  def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
    super
  end

  # Radio button - keep default styling
  def radio_button(method, tag_value, options = {})
    super
  end

  # Label - automatically adds required indicator (*) and form-label class
  # Options:
  #   - required: true/false - manually control required indicator
  #   - If not specified, automatically detects from model validations
  #
  # Usage:
  #   form.label :name                                    # Auto-detect
  #   form.label :name, required: true                    # Force show *
  #   form.label :name, "Name", required: true            # With custom text
  #   form.label :name, required: true do "Name" end      # With block
  def label(method, text = nil, options = {}, &block)
    # Smart parameter handling: if text is a Hash, treat it as options
    if text.is_a?(Hash) && options.empty?
      options = text
      text = nil
    end

    # Extract required option (can be true, false, or nil)
    show_required = options.delete(:required)

    # If not manually specified, check model validations
    show_required = field_required?(method) if show_required.nil?

    # Add form-label class
    options[:class] = [options[:class], 'form-label'].compact.join(' ') unless options[:class]&.include?('form-label')

    super(method, text, options) do
      content = block_given? ? @template.capture(&block) : (text || method.to_s.humanize)
      show_required ? @template.safe_join([content, @template.content_tag(:span, ' *', class: 'text-red-500')]) : content
    end
  end

  private

  # Wrap field with error message if validation errors exist
  def field_with_errors(method)
    field_html = yield

    if @object && @object.errors[method].any?
      # Join all error messages with " / "
      error_text = @object.errors[method].join(' / ')
      error_message = @template.content_tag(:p, error_text, class: 'form-error')

      field_html + error_message
    else
      field_html
    end
  end

  # Add a CSS class to options, merging with existing classes
  def add_default_class!(options, css_class)
    options[:class] = [options[:class], css_class].compact.join(' ')
  end

  # Add error class if field has validation errors
  def add_error_class!(options, method)
    if @object && @object.errors[method].any?
      options[:class] = [options[:class], 'field-error'].compact.join(' ')
    end
  end

  # Add a Stimulus controller to data attributes
  def add_stimulus_controller!(options, controller_name)
    options[:data] ||= {}

    # Handle existing controller attribute
    existing_controller = options[:data][:controller]
    if existing_controller.present?
      # Don't add if already present
      controllers = existing_controller.split(' ')
      unless controllers.include?(controller_name)
        options[:data][:controller] = "#{existing_controller} #{controller_name}"
      end
    else
      options[:data][:controller] = controller_name
    end
  end

  # Check if field is required based on model validations
  def field_required?(method)
    return false unless @object && @object.class.respond_to?(:validators_on)

    validators = @object.class.validators_on(method)
    validators.any? do |validator|
      validator.is_a?(ActiveModel::Validations::PresenceValidator)
    end
  end
end
