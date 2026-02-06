require_relative 'herb_stimulus_parser'

# Shared helper methods for Stimulus validation specs
module StimulusValidationHelpers
  # Parse action string into component parts
  def parse_action_string(action_string)
    return [] unless action_string

    actions = []

    # Split by whitespace, but be careful about complex action strings
    action_parts = action_string.scan(/\S+/)

    action_parts.each do |action|
      # Improved regex to handle more action formats
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

  # Find exempt methods (webhook/callback methods) in AST
  def find_exempt_methods(node, content, exempt_ranges)
    return unless node

    if node.type == :def
      method_name = node.children[0].to_s

      # Check if method name is webhook/callback or ends with _webhook/_callback
      if method_name.match?(/(^|_)(webhook|callback)$/)
        # Get line range for this method
        start_line = node.loc.line
        end_line = node.loc.last_line
        exempt_ranges << (start_line..end_line)
      end
    end

    # Recursively search child nodes
    node.children.each do |child|
      find_exempt_methods(child, content, exempt_ranges) if child.is_a?(Parser::AST::Node)
    end
  end

  # Find ActionCable broadcasts in AST
  def find_actioncable_broadcasts_in_ast(node, local_vars = nil)
    # Initialize local_vars hash on first call
    local_vars ||= {}

    return [] unless node

    broadcasts = []

    # Track local variable assignments in current scope
    if node.type == :lvasgn
      var_name = node.children[0]
      var_value_node = node.children[1]
      if var_value_node
        # Extract string value from assignment
        extracted = extract_string_from_node(var_value_node)
        if extracted
          local_vars[var_name] = extracted
        end
      end
    end

    # Find ActionCable.server.broadcast calls
    if node.type == :send && is_actioncable_broadcast?(node)
      stream_name = extract_broadcast_stream_name(node, local_vars)
      broadcasts << {
        type: extract_broadcast_type_from_node(node),
        stream_name: stream_name,
        line: node.loc.line
      }
    end

    # Recursively search child nodes (pass the same local_vars reference)
    if node.respond_to?(:children)
      node.children.each do |child|
        if child.is_a?(Parser::AST::Node)
          broadcasts.concat(find_actioncable_broadcasts_in_ast(child, local_vars))
        end
      end
    end

    broadcasts
  end

  # Extract string from AST node (handles plain strings and interpolated strings)
  def extract_string_from_node(node)
    return nil unless node

    case node.type
    when :str
      # Plain string: "chat_123"
      node.children[0]
    when :dstr
      # Interpolated string: "chatzzz_#{chat_id}"
      # AST structure: (dstr (str "chatzzz_") (begin (lvar :chat_id)))
      # Extract the first static string part
      node.children.each do |part|
        if part.is_a?(Parser::AST::Node) && part.type == :str
          return part.children[0] if !part.children[0].empty?
        end
      end
      nil
    else
      nil
    end
  end

  # Check if node is an ActionCable broadcast call
  def is_actioncable_broadcast?(node)
    return false unless node.type == :send && node.children[1] == :broadcast
    receiver = node.children[0]
    return false unless receiver && receiver.type == :send && receiver.children[1] == :server
    receiver_receiver = receiver.children[0]
    receiver_receiver && receiver_receiver.type == :const && receiver_receiver.children[1] == :ActionCable
  end

  # Extract broadcast stream name from broadcast node
  def extract_broadcast_stream_name(broadcast_node, local_vars = {})
    first_arg = broadcast_node.children[2]
    return nil unless first_arg

    case first_arg.type
    when :str
      # Direct string: "chat_123"
      first_arg.children[0]
    when :dstr
      # Interpolated string: "chat_#{id}"
      # Extract first static string part
      first_arg.children.each do |part|
        if part.is_a?(Parser::AST::Node) && part.type == :str
          return part.children[0] if !part.children[0].empty?
        end
      end
      nil
    when :lvar
      # Variable reference: channel_name
      # Look up the variable value in local_vars hash
      var_name = first_arg.children[0]
      local_vars[var_name]
    else
      nil
    end
  end

  # Extract broadcast type from broadcast node
  def extract_broadcast_type_from_node(broadcast_node)
    broadcast_node.children[2..-1].each do |arg|
      next unless arg.is_a?(Parser::AST::Node) && arg.type == :hash
      arg.children.each do |pair|
        next unless pair.type == :pair
        key, value = pair.children[0], pair.children[1]
        is_type_key = (key.type == :sym && key.children[0] == :type) || (key.type == :str && key.children[0] == 'type')
        return value.children[0] if is_type_key && value.type == :str
      end
    end
    nil
  end

  # Infer channel name from stream name
  def infer_channel_name_from_stream(stream_name)
    return nil unless stream_name
    # Remove trailing _digits pattern: "chat_123" -> "chat"
    # Also remove trailing underscore for inline interpolation: "chat_" -> "chat"
    stream_name.sub(/_\d+$/, '').chomp('_')
  end

  # Capitalize type string for comparison
  def capitalize_type(type_string)
    type_string.split(/[-_]/).map(&:capitalize).join('')
  end

  # Parse ERB actions from content using Herb
  def parse_erb_actions(content, relative_path)
    actions = []

    # Use Herb-based parser to find actions in ERB blocks
    parser = StimulusValidation::HerbStimulusParser.new(content, relative_path)
    parser.parse

    parser.actions.each do |action_info|
      actions << {
        element: nil, # ERB actions don't have direct DOM elements
        action: action_info[:action_string],
        event: action_info[:event],
        controller: action_info[:controller],
        method: action_info[:method],
        source: 'erb_ast',
        line_number: action_info[:location] ? action_info[:location].start.line : 1,
        line_content: action_info[:action_string]
      }
    end

    actions
  end

  # Check if ERB action is within the controller scope
  def check_erb_action_scope(action_info, content, relative_path, herb_parser)
    controller_name = action_info[:controller]
    action_line = action_info[:line_number]

    # Find all controller definitions in the file using AST parsing
    controller_scopes = []
    lines = content.split("\n")

    # First, check for HTML data-controller attributes
    lines.each_with_index do |line, index|
      line_num = index + 1

      # Check for data-controller attribute using simple string matching
      if line.include?('data-controller=') && line.include?(controller_name)
        # Verify it's actually the controller name (not a substring)
        if line.include?("\"#{controller_name}\"") || line.include?("'#{controller_name}'") ||
           line.include?("\"#{controller_name} ") || line.include?("'#{controller_name} ") ||
           line.include?(" #{controller_name}\"") || line.include?(" #{controller_name}'") ||
           line.include?(" #{controller_name} ")

          # Find the scope boundaries for this controller
          scope_start = line_num
          scope_end = find_scope_end(lines, index)
          controller_scopes << { start: scope_start, end: scope_end, line: line.strip }
        end
      end
    end

    # Second, check for ERB controller definitions using herb_parser
    herb_parser.controllers.each do |controller_info|
      if controller_info[:controller_name] == controller_name && controller_info[:location]
        block_start_line = controller_info[:location].start.line
        # For ERB controllers, consider the scope from start to a reasonable range
        # This is a simplified approach - we assume controller scope extends reasonably far
        block_end_line = block_start_line + 100 # Reasonable default

        controller_scopes << {
          start: block_start_line,
          end: block_end_line,
          line: "ERB controller: #{controller_name}"
        }
      end
    end

    # Check if action line is within any controller scope
    in_scope = controller_scopes.any? do |scope|
      action_line >= scope[:start] && action_line <= scope[:end]
    end

    in_scope
  end

  # Find the end line of an ERB block starting from a specific line number
  def find_erb_block_end_line(content, block, start_line = nil)
    # If start_line is provided, use it; otherwise use block position
    if start_line
      # Find the position in content corresponding to start_line
      lines = content.split("\n")
      start_pos = lines[0...start_line-1].join("\n").length
      start_pos += 1 if start_line > 1  # Account for newline
    else
      start_pos = block[:position][0]
    end

    # Search forward from the start position to find the matching end tag
    remaining_content = content[start_pos..-1]

    # Count lines before the start position
    lines_before_start = content[0...start_pos].count("\n")

    # For merged blocks that contain 'do' and 'end', find the matching end
    if block[:merged] || block[:code].include?(' do')
      # Find the position of the closing <% end %> tag
      end_match = remaining_content.match(/<%\s*end\s*%>/)
      if end_match
        end_pos = start_pos + end_match.end(0)
        lines_in_block = content[start_pos...end_pos].count("\n")
        return lines_before_start + lines_in_block + 1
      end
    end

    # For single-line blocks or blocks without 'do', the scope is just the current line
    # plus any content within the same HTML element
    lines_before_start + 1
  end

  # Find the end of a scope starting from the given line index
  def find_scope_end(lines, start_index)
    # Find the opening tag that contains data-controller
    start_line = lines[start_index]

    # Look for the opening tag by searching backwards from the data-controller line
    # This handles multi-line HTML attributes like:
    #   <div
    #     class="..."
    #     data-controller="file-upload"
    #     ...
    #   >
    opening_tag_line = nil
    tag_name = nil

    # Search backwards up to 20 lines to find the opening tag
    search_start = [start_index - 20, 0].max
    (search_start..start_index).reverse_each do |line_idx|
      line = lines[line_idx]
      # Match opening tag: <tagname ... (may not be closed on this line)
      if match = line.match(/<(\w+)(?:\s|$)/)
        # Found a tag opening, now verify it's not already closed
        # Check if this tag closes before our start_index line
        tag_closes_early = false
        (line_idx..start_index).each do |check_idx|
          check_line = lines[check_idx]
          if check_line.match(/<\/#{match[1]}>/)
            tag_closes_early = true
            break
          end
        end

        unless tag_closes_early
          tag_name = match[1]
          opening_tag_line = line_idx
          break
        end
      end
    end

    return lines.length unless tag_name

    # Count nested tags to find the matching closing tag
    depth = 0
    tag_found = false

    (opening_tag_line...lines.length).each do |i|
      line = lines[i]

      # Look for opening tags
      line.scan(/<#{tag_name}(?:\s|>)/) do
        depth += 1
        tag_found = true
      end

      # Look for closing tags
      line.scan(/<\/#{tag_name}>/) do
        depth -= 1
        if depth == 0 && tag_found
          return i + 1
        end
      end
    end

    # If no matching closing tag found, assume scope extends to end of file
    lines.length
  end
end
