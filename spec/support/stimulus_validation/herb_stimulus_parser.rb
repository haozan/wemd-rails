require 'herb'
require 'parser/current'

module StimulusValidation
  # Visitor to collect Stimulus-related data from ERB templates
  class StimulusVisitor < Herb::Visitor
    attr_reader :controllers, :actions, :targets, :values

    def initialize(source, filename)
      @source = source
      @filename = filename
      @controllers = []
      @actions = []
      @targets = []
      @values = []
      super()
    end

    # Visit HTML element nodes to collect static data-* attributes
    def visit_html_element_node(node)
      collect_static_attributes(node)
      super(node)  # Continue visiting children
    end

    # Visit ERB content nodes (<%= ... %>) to collect dynamic data: { ... }
    def visit_erb_content_node(node)
      collect_erb_data(node, :output)
      super(node)
    end

    # Visit ERB block nodes (<%= ... do %> ... <% end %>)
    def visit_erb_block_node(node)
      collect_erb_data(node, :block)
      super(node)
    end

    private

    # Collect static HTML attributes like data-controller="foo"
    def collect_static_attributes(node)
      return unless node.respond_to?(:open_tag) && node.open_tag

      attributes = extract_attributes(node.open_tag)

      attributes.each do |attr_name, attr_value, attr_location|
        case attr_name
        when 'data-controller'
          # Split multiple controllers
          attr_value.split(/\s+/).each do |controller_name|
            @controllers << {
              controller_name: controller_name.strip,
              source: :html,
              location: attr_location,
              file: @filename
            }
          end

        when 'data-action'
          # Parse action string
          parsed_actions = parse_action_string(attr_value)
          parsed_actions.each do |action_info|
            @actions << {
              controller: action_info[:controller],
              method: action_info[:method],
              event: action_info[:event],
              action_string: action_info[:action],
              source: :html,
              location: attr_location,
              file: @filename
            }
          end

        when /^data-(.+)-target$/
          # Extract controller name from attribute
          controller_name = $1
          target_values = attr_value.split(/\s+/)
          target_values.each do |target_name|
            @targets << {
              controller: controller_name,
              target: target_name.strip,
              source: :html,
              location: attr_location,
              file: @filename
            }
          end

        when /^data-(.+)-(.+)-value$/
          # Extract controller and value name
          controller_name = $1
          value_name = $2.gsub('-', '_')
          @values << {
            controller: controller_name,
            value: value_name,
            source: :html,
            location: attr_location,
            file: @filename
          }
        end
      end
    end

    # Extract attributes from open_tag node
    def extract_attributes(open_tag)
      attributes = []

      if open_tag.respond_to?(:children) && open_tag.children
        open_tag.children.each do |child|
          next unless child.class.to_s.include?('HTMLAttribute')

          attr_name = extract_attribute_name(child)
          attr_value = extract_attribute_value(child)
          attr_location = child.location if child.respond_to?(:location)

          # Skip attributes with ERB interpolation (we'll handle those in ERB visitor)
          next if has_erb_interpolation?(child)

          attributes << [attr_name, attr_value, attr_location] if attr_name && attr_value
        end
      end

      attributes
    end

    def extract_attribute_name(attr_node)
      if attr_node.respond_to?(:name)
        name = attr_node.name
        if name.respond_to?(:value)
          name.value
        elsif name.is_a?(String)
          name
        end
      end
    end

    def extract_attribute_value(attr_node)
      if attr_node.respond_to?(:value)
        value = attr_node.value
        if value.respond_to?(:value)
          value.value
        elsif value.is_a?(String)
          value
        end
      end
    end

    def has_erb_interpolation?(node)
      return true if node.class.to_s.include?('ERB')

      if node.respond_to?(:children) && node.children
        node.children.any? { |child| child.class.to_s.include?('ERB') }
      else
        false
      end
    end

    # Collect data from ERB nodes
    def collect_erb_data(node, type)
      return unless node.respond_to?(:content)

      # Extract Ruby code from ERB
      code = extract_erb_code(node)
      return unless code

      # Only process if code contains 'data' keyword
      return unless code.include?('data')

      # For ERBBlockNode, add 'end' to complete the block syntax
      # Example: "button_to path, data: { ... } do " -> "button_to path, data: { ... } do\nend"
      code += "\nend" if type == :block

      # Parse Ruby code to extract data: { ... } hashes
      ast = Parser::CurrentRuby.parse(code)
      extract_stimulus_from_ast(ast, node.location, type)
    end

    def extract_erb_code(node)
      content = node.content
      if content.respond_to?(:value)
        content.value
      elsif content.is_a?(String)
        content
      end
    end

    # Extract Stimulus data from Ruby AST
    def extract_stimulus_from_ast(ast_node, location, erb_type)
      return unless ast_node

      # Look for data: { ... } hash arguments in method calls
      if ast_node.type == :send
        extract_from_method_call(ast_node, location, erb_type)
      end

      # Recursively search child nodes
      if ast_node.respond_to?(:children)
        ast_node.children.each do |child|
          next unless child.is_a?(Parser::AST::Node)
          extract_stimulus_from_ast(child, location, erb_type)
        end
      end
    end

    def extract_from_method_call(send_node, location, erb_type)
      # Look for hash arguments
      send_node.children[2..-1].each do |arg|
        next unless arg.is_a?(Parser::AST::Node)

        # Find hash with :data key
        if arg.type == :hash
          process_data_hash(arg, location, erb_type)
        end
      end
    end

    def process_data_hash(hash_node, location, erb_type)
      hash_node.children.each do |pair|
        next unless pair.type == :pair

        key_node = pair.children[0]
        value_node = pair.children[1]

        # Check if key is :data or "data"
        key_name = case key_node.type
                   when :sym then key_node.children[0].to_s
                   when :str then key_node.children[0]
                   else next
                   end

        next unless key_name == 'data'

        # Process the data hash value
        if value_node.type == :hash
          extract_data_attributes(value_node, location, erb_type)
        end
      end
    end

    def extract_data_attributes(data_hash, location, erb_type)
      data_hash.children.each do |pair|
        next unless pair.type == :pair

        key_node = pair.children[0]
        value_node = pair.children[1]

        # Get attribute name
        attr_name = case key_node.type
                    when :sym then key_node.children[0].to_s
                    when :str then key_node.children[0]
                    else next
                    end

        # Get attribute value (only for string values)
        next unless value_node.type == :str
        attr_value = value_node.children[0]

        # Process based on attribute type
        case attr_name
        when 'controller'
          # Split multiple controllers
          attr_value.split(/\s+/).each do |controller_name|
            @controllers << {
              controller_name: controller_name.strip,
              source: :erb,
              location: location,
              file: @filename
            }
          end

        when 'action'
          # Parse action string
          parsed_actions = parse_action_string(attr_value)
          parsed_actions.each do |action_info|
            @actions << {
              controller: action_info[:controller],
              method: action_info[:method],
              event: action_info[:event],
              action_string: action_info[:action],
              source: :erb,
              location: location,
              file: @filename
            }
          end

        else
          # Check if it's a target attribute: controller_name_target
          if attr_name =~ /^(.+)_target$/
            controller_name = $1.gsub('_', '-')
            @targets << {
              controller: controller_name,
              target: attr_value,
              source: :erb,
              location: location,
              file: @filename
            }
          end
        end
      end
    end

    # Parse action string like "click->controller#method"
    def parse_action_string(action_string)
      return [] unless action_string

      actions = []
      action_parts = action_string.scan(/\S+/)

      action_parts.each do |action|
        if match = action.match(/^(?:(\w+(?:\.\w+)*)->)?(\w+(?:-\w+)*)#(\w+)(?:@\w+)?$/)
          event, controller_name, method_name = match[1], match[2], match[3]
          actions << {
            action: action,
            event: event,
            controller: controller_name,
            method: method_name
          }
        end
      end

      actions
    end

    def location_to_line(location)
      return 1 unless location
      location.start.line
    end
  end

  # Main parser class
  class HerbStimulusParser
    attr_reader :controllers, :actions, :targets, :values

    def initialize(source, filename)
      @source = source
      @filename = filename
      @controllers = []
      @actions = []
      @targets = []
      @values = []
    end

    def parse
      begin
        # Parse ERB template using Herb
        result = Herb.parse(@source)

        # Create visitor and traverse AST
        visitor = StimulusVisitor.new(@source, @filename)
        result.visit(visitor)

        # Collect results
        @controllers = visitor.controllers
        @actions = visitor.actions
        @targets = visitor.targets
        @values = visitor.values

        true
      rescue => e
        Rails.logger.error "HerbStimulusParser error: #{e.message}\n#{e.backtrace.join("\n")}" if defined?(Rails)
        false
      end
    end
  end
end
