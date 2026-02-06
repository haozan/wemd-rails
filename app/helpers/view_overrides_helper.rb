module ViewOverridesHelper
  # Generate `{controller}-{action}-page` class for body element
  def body_class
    path = controller_path.tr('/_', '-')
    action_name_map = {
      index: 'index',
      new: 'edit',
      edit: 'edit',
      update: 'edit',
      patch: 'edit',
      create: 'edit',
      destory: 'index'
    }
    mapped_action_name = action_name_map[action_name.to_sym] || action_name
    body_class_page = format('%s-%s-page', path, mapped_action_name)
    body_class_page
  end

  def current_path
    request.env['PATH_INFO']
  end

  # Flash message class helper
  def flash_alert_class(level)
    case level.to_sym
    when :notice, :success
      'alert-success'
    when :info
      'alert-info'
    when :warning
      'alert-warning'
    when :alert, :error, :danger
      'alert-danger'
    when :tips
      'alert-warning'
    else
      'alert-info'
    end
  end

  # This prevents AI from trying to add non-existent themes and rescue total_pages errors
  def paginate(scope, **options)
    super(scope, **options.except(:theme))
  rescue => e
    Rails.logger.error("Pagination error, ignored : #{e.message}")
    ''
  end

  # Action badge class for operation logs
  def action_badge_class(action)
    case action
    when 'login'
      'badge-success dark:badge-success'
    when 'logout'
      'badge-secondary dark:badge-secondary'
    when 'create'
      'badge-secondary dark:badge-secondary'
    when 'update'
      'badge-warning dark:badge-warning'
    when 'destroy'
      'badge-danger dark:badge-danger'
    else
      'badge-neutral dark:badge-neutral'
    end
  end

  # Override button_to to fix AI's common mistake
  # AI often writes: button_to 'Text', url, options do ... end
  # But correct syntax is: button_to url, options do ... end
  def button_to(name = nil, options = nil, html_options = nil, &block)
    if block_given?
      # When block is given, first param should be URL, not text
      # If name looks like text and options looks like URL, fix it
      if name.is_a?(String) && !name.start_with?('/', 'http') && options.is_a?(String)
        # AI mistake detected: button_to 'Text', '/', options do...
        # Ignore the text, use options as URL
        super(options, html_options, &block)
      else
        # Correct usage: button_to '/', options do...
        super(name, options, html_options, &block)
      end
    else
      # Normal button_to without block
      super
    end
  end

  # Override link_to to fix AI's common mistake
  # Similar issue: AI might pass redundant parameters with blocks
  def link_to(name = nil, options = nil, html_options = nil, &block)
    if block_given?
      # When block is given, first param should be URL
      # If name looks like text and options looks like URL, fix it
      if name.is_a?(String) && !name.start_with?('/', 'http', '#') && options.is_a?(String)
        # AI mistake: link_to 'Text', '/', options do...
        # Ignore the text, use options as URL
        super(options, html_options, &block)
      else
        # Correct usage: link_to '/', options do...
        super(name, options, html_options, &block)
      end
    else
      # Normal link_to without block
      super
    end
  end

  # Override lucide_icon to handle missing icons gracefully
  # If the requested icon doesn't exist, show a default icon instead
  def lucide_icon(name, **options)
    icon_name = name.to_s
    default_icon = 'help-circle'

    begin
      # Try to render the requested icon
      super(icon_name, **options)
    rescue => e
      # If icon not found, show default icon
      if e.message.include?('Unknown icon')
        Rails.logger.warn("Missing lucide icon: #{icon_name}, using fallback: #{default_icon}")
        super(default_icon, **options)
      else
        raise
      end
    end
  end
end
