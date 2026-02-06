class ControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :actions, type: :array, default: [], banner: "action action"

  class_option :auth, type: :boolean, default: false, desc: "Generate controller with authentication required"
  class_option :single, type: :boolean, default: false, desc: "Generate singular resource (resource instead of resources)"

  # Auto-fix common namespace separator mistakes (runs first)
  def normalize_name
    if name.include?(':') && !name.include?('::')
      original_name = name.dup
      self.name = name.gsub(':', '::')
      say "⚠️  Auto-corrected namespace separator:", :yellow
      say "    #{original_name} → #{name}", :yellow
      say "    (Use '::' for namespaces, not ':')", :cyan
    end
  end

  def generate_controller
    validate_inputs!
    template "controller.rb.erb", controller_file_path
  end

  def generate_request_spec
    template "request_spec.rb.erb", spec_file_path
  end

  def create_view_directories
    # Create the view directory for the controller (skip for API controllers)
    empty_directory view_path unless is_api_controller?
  end

  def add_routes
    if behavior == :invoke
      # Creating routes
      if options[:single]
        if route_options.nil?
          # Has custom actions, use do-end block
          route_with_custom_actions("resource :#{singular_name}")
        else
          add_simple_route("resource :#{singular_name}#{route_options}")
        end
      else
        if route_options.nil?
          # Has custom actions, use do-end block
          route_with_custom_actions("resources :#{plural_name}")
        else
          add_simple_route("resources :#{plural_name}#{route_options}")
        end
      end
    else
      # Destroying routes
      remove_routes
    end
  end

  def show_completion_message
    # Display generated controller file content (only when creating)
    if behavior != :revoke
      say "\n"
      say "📄 Generated controller (#{controller_file_path}):", :green
      say "━" * 60, :green
      File.readlines(controller_file_path).each_with_index do |line, index|
        puts "#{(index + 1).to_s.rjust(4)} │ #{line.chomp}"
      end
      say "━" * 60, :green

      # Display added routes
      if @added_routes_content
        say "\n"
        say "📄 Added routes (config/routes.rb):", :green
        say "━" * 60, :green
        @added_routes_content.each do |line|
          puts "       │ #{line}"
        end
        say "━" * 60, :green
      end

      say "\n"
      say "✅ Above is the latest content - no need to read files again", :cyan
      say "\n"
      say "Controller and tests generated successfully!", :green

      unless is_api_controller?
        say "📁 View directory created: #{view_path}/", :green
        say "📄 Please create and edit view files manually as needed:", :yellow
        say "\n"

        selected_actions.each do |action|
          case action
          when 'index'
            say "  #{view_path}/index.html.erb", :blue unless options[:single]
          when 'show'
            say "  #{view_path}/show.html.erb", :blue
          when 'new'
            say "  #{view_path}/new.html.erb", :blue
          when 'edit'
            say "  #{view_path}/edit.html.erb", :blue
          end
        end
      else
        say "API controller generated - no views needed", :cyan
      end

      say "\n"
      if options[:single]
        say "Tip: This is a singular resource - routes don't need :id parameter", :cyan
      end
    end
  end

  private

  # Helper methods for namespace and API detection
  def has_namespace?
    name.include?('::')
  end

  def is_api_controller?
    name.downcase.start_with?('api::')
  end

  def namespaces
    return [] unless has_namespace?
    parts = name.split('::')
    parts[0..-2].map(&:underscore)
  end

  def resource_name_without_namespace
    return name unless has_namespace?
    name.split('::').last
  end

  # Validate all inputs before generating files
  def validate_inputs!
    return if options[:force_override]

    check_invalid_syntax
    check_user_model
    check_name_validity
    check_controller_conflicts
    check_single_resource_actions
  end

  # Check for invalid syntax
  def check_invalid_syntax
    if name.include?('+') || actions.any? { |a| a.include?('+') }
      say "Error: Cannot use '+' in generator. Generate one controller at a time.", :red
      exit(1)
    end
  end

  # Check if User model exists when using --auth
  def check_user_model
    return unless options[:auth]

    unless File.exist?("app/models/user.rb")
      say "Error: --auth requires User model (app/models/user.rb not found).", :red
      say "\n💡 Solution:", :blue
      say "  Generate authentication:  rails generate authentication", :blue
      say "  Remove --auth flag:       rails g controller #{name} #{actions.join(' ')}", :blue
      exit(1)
    end
  end

  # Check controller name validity
  def check_name_validity
    # Check for reserved words first (before processing)
    if %w[controller controllers].include?(name.downcase)
      say "Error: Cannot generate controller with name '#{name}'.", :red
      say "This name is reserved. Please choose a different name.", :yellow
      say "Example: rails generate controller products", :blue
      exit(1)
    end

    # Check for empty or invalid names after processing
    if base_name_without_controller.blank?
      say "Error: Controller name cannot be empty after processing.", :red
      say "Usage: rails generate controller NAME [actions]", :yellow
      say "Example: rails generate controller products", :blue
      exit(1)
    end

    # Check for minimum length (at least 2 characters)
    if base_name_without_controller.length < 2
      say "Error: Controller name must be at least 2 characters long.", :red
      say "Single letter controller names can cause naming conflicts.", :yellow
      say "Example: rails generate controller posts", :blue
      exit(1)
    end
  end

  # Check for controller conflicts with system controllers
  def check_controller_conflicts
    # Special check for home controller
    if singular_name == 'home' || plural_name == 'home'
      say "Error: Cannot generate 'home' controller - it already exists in the system.", :red
      say "💡 To add home page functionality:", :blue
      say "   Create and edit app/views/home/index.html.erb directly", :blue
      say "\n⚠️  Important: Write real business logic, do not reference any demo files", :yellow
      exit(1)
    end

    if protected_controller_names.include?(plural_name)
      conflict_reason = case plural_name
                       when 'tmp', 'tmps'
                         "as it conflicts with development middleware and temporary file system"
                       else
                         "as it conflicts with authentication system"
                       end

      say "Error: Cannot generate controller for '#{plural_name}' #{conflict_reason}.", :red
      say "The following controller names are protected:", :yellow
      protected_controller_names.each { |name| say "  - #{name}", :yellow }
      say "\nSolutions:", :blue
      say "1. Choose a different controller name to avoid conflicts", :blue
      say "2. Use a different name for your controller", :blue
      exit(1)
    end
  end

  # Check single resource actions validity
  def check_single_resource_actions
    if options[:single] && selected_actions.include?('index')
      say "Error: --single flag conflicts with 'index' action.", :red
      say "\n💡 Solution:", :blue
      say "  Remove --single:  rails g controller #{name} #{actions.join(' ')}", :blue
      say "  Remove index:     rails g controller #{name} #{(actions - ['index']).join(' ')} --single", :blue
      exit(1)
    end
  end

  def base_name_without_controller
    # Remove '_controller' or '_controllers' suffix if present (case insensitive)
    if has_namespace?
      resource_name_without_namespace.gsub(/_?controllers?$/i, '')
    else
      name.gsub(/_?controllers?$/i, '')
    end
  end

  def singular_name
    base_name_without_controller.underscore.singularize
  end

  def plural_name
    base_name_without_controller.underscore.pluralize
  end

  def class_name
    if has_namespace?
      # Build proper class name: api::v1::posts => Api::V1::Posts, admin::posts => Admin::Posts
      parts = name.split('::')
      # Keep the last part pluralized for controller name
      namespace_parts = parts[0..-2].map { |part| part.classify }
      controller_part = parts.last.gsub(/_?controllers?$/i, '').classify.pluralize
      (namespace_parts + [controller_part]).join('::')
    else
      base_name_without_controller.classify.pluralize
    end
  end

  def controller_file_path
    if has_namespace?
      "app/controllers/#{namespaces.join('/')}/#{plural_name}_controller.rb"
    else
      "app/controllers/#{plural_name}_controller.rb"
    end
  end

  def spec_file_path
    if has_namespace?
      "spec/requests/#{namespaces.join('/')}/#{plural_name}_spec.rb"
    else
      "spec/requests/#{plural_name}_spec.rb"
    end
  end

  def view_path
    if has_namespace?
      "app/views/#{namespaces.join('/')}/#{plural_name}"
    else
      "app/views/#{plural_name}"
    end
  end

  def parent_controller_class
    if is_api_controller?
      "Api::BaseController"
    else
      "ApplicationController"
    end
  end

  # Generate route path helper prefix (e.g., api_v1_posts_path for api::v1::posts)
  def route_path_prefix
    if has_namespace?
      namespaces.join('_') + '_'
    else
      ''
    end
  end

  # Generate full path helper name (e.g., api_v1_posts_path)
  def plural_route_path
    "#{route_path_prefix}#{plural_name}_path"
  end

  # Generate singular path helper name (e.g., api_v1_post_path)
  def singular_route_path
    "#{route_path_prefix}#{singular_name}_path"
  end

  # Generate new path helper name (e.g., new_api_v1_post_path)
  def new_route_path
    "new_#{route_path_prefix}#{singular_name}_path"
  end

  # Generate edit path helper name (e.g., edit_api_v1_post_path)
  def edit_route_path
    "edit_#{route_path_prefix}#{singular_name}_path"
  end

  def selected_actions
    if actions.empty?
      if options[:single]
        %w[show new edit]  # 单一资源不包含 index
      else
        %w[index show new edit]
      end
    else
      actions
    end
  end

  def requires_authentication?
    options[:auth]
  end

  def single_resource?
    options[:single]
  end

  def protected_controller_names
    %w[
      sessions
      registrations
      passwords
      profiles
      invitations
      omniauths
      orders
      tmps
    ]
  end

  def controller_actions
    actions_code = []

    # Add CRUD actions
    crud_actions_to_generate.each do |action|
      case action
      when 'index' then actions_code << index_action
      when 'show' then actions_code << show_action
      when 'new' then actions_code << new_action
      when 'create' then actions_code << create_action
      when 'edit' then actions_code << edit_action
      when 'update' then actions_code << update_action
      when 'destroy' then actions_code << destroy_action
      end
    end

    # Add non-CRUD actions
    non_crud_actions.each do |action|
      actions_code << custom_action(action)
    end

    actions_code.join("\n\n")
  end

  def route_options
    if actions.empty?
      ""
    elsif has_full_crud? && has_only_crud_actions?
      ""  # Full resources without only restriction and no custom actions
    elsif has_only_crud_actions?
      ", only: [:#{route_actions.join(', :')}]"
    else
      # Has custom actions, need do-end block
      nil  # Will be handled in add_routes method
    end
  end

  def index_action
    <<-ACTION
  def index
    # Write your real logic here
  end
    ACTION
  end

  def show_action
    <<-ACTION
  def show
    # Write your real logic here
  end
    ACTION
  end

  def new_action
    <<-ACTION
  def new
    # Write your real logic here
  end
    ACTION
  end

  def create_action
    <<-ACTION
  def create
    # Write your real logic here
  end
    ACTION
  end

  def edit_action
    <<-ACTION
  def edit
    # Write your real logic here
  end
    ACTION
  end

  def update_action
    <<-ACTION
  def update
    # Write your real logic here
  end
    ACTION
  end

  def destroy_action
    <<-ACTION
  def destroy
    # Write your real logic here
  end
    ACTION
  end

  def custom_action(action_name)
    <<-ACTION
  def #{action_name}
    # Write your real logic here
  end
    ACTION
  end

  # Helper methods for route generation
  def crud_actions_to_generate
    actions = []

    # Include explicitly specified actions
    selected_actions.each do |action|
      case action
      when 'index', 'show', 'new', 'edit', 'create', 'update', 'destroy'
        actions << action
      end
    end

    # Auto-add paired actions only if not explicitly specified
    if selected_actions.include?('new') && !selected_actions.include?('create')
      actions << 'create'
    end

    if selected_actions.include?('edit') && !selected_actions.include?('update')
      actions << 'update'
    end

    # Only auto-add destroy if new or edit is present but destroy is not explicitly specified
    if selected_actions.any? { |action| %w[new edit].include?(action) } && !selected_actions.include?('destroy')
      actions << 'destroy'
    end

    actions.uniq
  end

  def non_crud_actions
    # HTTP methods and user-facing CRUD actions should not be in member blocks
    standard_actions = %w[index show new edit create update destroy]
    selected_actions.reject { |action| standard_actions.include?(action) }
  end

  def has_full_crud?
    return false if actions.empty?

    expected_crud = if options[:single]
      %w[show new edit create update destroy]
    else
      %w[index show new edit create update destroy]
    end

    # Check if all expected CRUD actions are present (allow additional custom actions)
    expected_crud.all? { |action| selected_actions.include?(action) }
  end

  def has_only_crud_actions?
    non_crud_actions.empty?
  end

  def route_actions
    actions = []

    selected_actions.each do |action|
      case action
      when 'index', 'show', 'new', 'edit', 'create', 'update', 'destroy'
        actions << action
      end
    end

    # Auto-add paired actions only if not explicitly specified
    if selected_actions.include?('new') && !selected_actions.include?('create')
      actions << 'create'
    end

    if selected_actions.include?('edit') && !selected_actions.include?('update')
      actions << 'update'
    end

    # Only auto-add destroy if new or edit is present but destroy is not explicitly specified
    if selected_actions.any? { |action| %w[new edit].include?(action) } && !selected_actions.include?('destroy')
      actions << 'destroy'
    end

    actions.uniq
  end

  def route_with_custom_actions(base_route)
    controller_name = options[:single] ? singular_name : plural_name

    if has_namespace?
      add_namespaced_route_with_custom_actions(base_route, controller_name)
    else
      add_root_route_with_custom_actions(base_route, controller_name)
    end
  end

  def add_root_route_with_custom_actions(base_route, controller_name)
    route_lines = []

    # Add comment marker for identification
    route_lines << "  # Routes for #{controller_name} generated by controller generator"

    if route_actions.any? && !has_full_crud?
      # Has some CRUD actions but not all - include them with only
      route_lines << "  #{base_route}, only: [:#{route_actions.join(', :')}] do"
    else
      # Either no CRUD actions or has full CRUD - just the base route
      route_lines << "  #{base_route} do"
    end

    # Add custom actions as collection routes (no :id parameter needed)
    # Change to 'on: :member' if the action needs :id parameter
    if non_crud_actions.any?
      non_crud_actions.each do |action|
        route_lines << "    get :#{action}, on: :collection"
      end
    end

    route_lines << "  end"
    route_lines << "  # End routes for #{controller_name}"

    # Calculate insertion line number
    routes_content = File.read('config/routes.rb')
    draw_line_index = routes_content.lines.index { |line| line.include?('Rails.application.routes.draw do') }
    @added_routes_start_line = draw_line_index + 2  # Line after "draw do"
    @added_routes_content = route_lines

    inject_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
      route_lines.join("\n") + "\n\n"
    end
  end

  def add_namespaced_route_with_custom_actions(base_route, controller_name)
    routes_content = File.read('config/routes.rb')

    # Find or create the namespace blocks
    insertion_point = find_or_create_namespace_blocks(routes_content)

    route_lines = []
    indent = "  " * (namespaces.length + 1)  # 2 spaces per namespace level

    # Add route with custom actions
    if route_actions.any? && !has_full_crud?
      route_lines << "#{indent}#{base_route}, only: [:#{route_actions.join(', :')}] do"
    else
      route_lines << "#{indent}#{base_route} do"
    end

    # Add custom actions as collection routes
    if non_crud_actions.any?
      non_crud_actions.each do |action|
        route_lines << "#{indent}  get :#{action}, on: :collection"
      end
    end

    route_lines << "#{indent}end"

    @added_routes_content = route_lines

    inject_into_file 'config/routes.rb', after: insertion_point do
      route_lines.join("\n") + "\n"
    end
  end

  def add_simple_route(route_line)
    controller_name = options[:single] ? singular_name : plural_name

    if has_namespace?
      add_namespaced_simple_route(route_line, controller_name)
    else
      add_root_simple_route(route_line, controller_name)
    end
  end

  def add_root_simple_route(route_line, controller_name)
    route_lines = [
      "  # Routes for #{controller_name} generated by controller generator",
      "  #{route_line}",
      "  # End routes for #{controller_name}"
    ]

    # Calculate insertion line number
    routes_content = File.read('config/routes.rb')
    draw_line_index = routes_content.lines.index { |line| line.include?('Rails.application.routes.draw do') }
    @added_routes_start_line = draw_line_index + 2  # Line after "draw do"
    @added_routes_content = route_lines

    inject_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
      route_lines.join("\n") + "\n\n"
    end
  end

  def add_namespaced_simple_route(route_line, controller_name)
    routes_content = File.read('config/routes.rb')

    # Find or create the namespace blocks
    insertion_point = find_or_create_namespace_blocks(routes_content)

    indent = "  " * (namespaces.length + 1)  # 2 spaces per namespace level
    route_lines = ["#{indent}#{route_line}"]

    @added_routes_content = route_lines

    inject_into_file 'config/routes.rb', after: insertion_point do
      route_lines.join("\n") + "\n"
    end
  end

  # Find or create nested namespace blocks and return the insertion point
  def find_or_create_namespace_blocks(routes_content)
    # Check if all necessary namespace blocks exist
    current_namespaces = []
    insertion_point = nil

    namespaces.each_with_index do |ns, index|
      current_namespaces << ns
      indent = "  " * (index + 1)
      namespace_pattern = /^#{Regexp.escape(indent)}namespace :#{ns} do\s*$/

      if routes_content.match(namespace_pattern)
        # Namespace exists, find the line after "namespace :xxx do"
        insertion_point = "#{indent}namespace :#{ns} do\n"
      else
        # Need to create this namespace
        if index == 0
          # Top-level namespace, add after draw do
          create_namespace_block_at_root(ns)
        else
          # Nested namespace, add inside parent
          parent_ns = current_namespaces[0..-2].join('/')
          create_nested_namespace_block(parent_ns, ns, index)
        end
        routes_content = File.read('config/routes.rb')  # Reload after modification
        insertion_point = "#{indent}namespace :#{ns} do\n"
      end
    end

    insertion_point
  end

  def create_namespace_block_at_root(namespace_name)
    namespace_block = [
      "  # API routes",
      "  namespace :#{namespace_name} do",
      "  end",
      ""
    ]

    inject_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
      namespace_block.join("\n") + "\n"
    end
  end

  def create_nested_namespace_block(parent_namespace, namespace_name, depth)
    indent = "  " * (depth + 1)
    parent_indent = "  " * depth
    insertion_point = "#{parent_indent}namespace :#{parent_namespace.split('/').last} do\n"

    namespace_block = "#{indent}namespace :#{namespace_name} do\n#{indent}end\n"

    inject_into_file 'config/routes.rb', after: insertion_point do
      namespace_block
    end
  end

  def remove_routes
    routes_file = File.join(destination_root, 'config/routes.rb')
    return unless File.exist?(routes_file)

    routes_content = File.read(routes_file)
    controller_name = options[:single] ? singular_name : plural_name

    # Look for routes using comment markers
    start_comment = "  # Routes for #{controller_name} generated by controller generator"
    end_comment = "  # End routes for #{controller_name}"

    if routes_content.include?(start_comment) && routes_content.include?(end_comment)
      # Remove section between comment markers (including the comments)
      pattern = /  # Routes for #{Regexp.escape(controller_name)} generated by controller generator.*?  # End routes for #{Regexp.escape(controller_name)}\n\n/m

      new_content = routes_content.gsub(pattern, '')
      File.write(routes_file, new_content)
      say "Removed routes for #{controller_name}", :green
    else
      say "Could not find marked routes for #{controller_name}. Please remove manually from config/routes.rb", :yellow
      say "Note: Routes generated by newer versions use comment markers for easier removal.", :blue
    end
  rescue => e
    say "Error removing routes: #{e.message}", :red
    say "Please manually remove routes for #{controller_name} from config/routes.rb", :yellow
  end

end
