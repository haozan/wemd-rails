require 'rails_helper'

RSpec.describe 'Turbo Architecture Validation', type: :system do
  include StimulusValidationHelpers

  # Initialize pipeline once for all tests
  let(:pipeline) { StimulusValidationPipeline.new }
  let(:controller_data) { pipeline.controller_data }
  let(:view_files) { pipeline.view_files }

  describe 'Turbo Frame Prohibition Validation' do
    it 'ensures Turbo Frames and turbo_stream_from are not used' do
      turbo_violations = []

      # Turbo Frame patterns to check in views (FORBIDDEN)
      view_turbo_patterns = {
        'turbo_frame_tag' => 'Turbo Frame helper',
        'data-turbo-frame' => 'Turbo Frame data attribute',
        '<turbo-frame' => 'Turbo Frame HTML tag',
        'turbo_stream_from' => 'turbo_stream_from helper'
      }

      # Turbo Frame patterns to check in controllers (FORBIDDEN)
      controller_turbo_patterns = {
        'turbo_frame_request?' => 'Turbo Frame request check'
      }

      # Files to skip from turbo_stream_from check
      skip_files = ['application.html.erb', 'admin.html.erb']

      # Check view files
      view_files.each do |view_file|
        content = File.read(view_file)
        relative_path = view_file.sub(Rails.root.to_s + '/', '')
        filename = File.basename(view_file)

        view_turbo_patterns.each do |pattern, description|
          # Skip turbo_stream_from check for application.html.erb and admin.html.erb
          if pattern == 'turbo_stream_from' && skip_files.include?(filename)
            next
          end

          if content.include?(pattern)
            turbo_violations << {
              file: relative_path,
              pattern: pattern,
              description: description,
              suggestion: "Remove #{description} - create .turbo_stream.erb templates for partial updates instead"
            }
          end
        end
      end

      # Check controller files
      controller_files = Dir.glob(Rails.root.join('app/controllers/**/*_controller.rb'))
      controller_files.each do |controller_file|
        content = File.read(controller_file)
        relative_path = controller_file.sub(Rails.root.to_s + '/', '')

        controller_turbo_patterns.each do |pattern, description|
          if content.include?(pattern)
            turbo_violations << {
              file: relative_path,
              pattern: pattern,
              description: description,
              suggestion: "Remove #{description} - Turbo Frames not allowed (use format.turbo_stream instead)"
            }
          end
        end
      end

      if turbo_violations.any?
        puts "\n❌ Turbo Frame/turbo_stream_from Violations (#{turbo_violations.length}):"
        turbo_violations.each do |violation|
          puts "   • #{violation[:file]}: Found '#{violation[:pattern]}' (#{violation[:description]})"
          puts "     ✅ Fix: #{violation[:suggestion]}"
        end

        error_details = turbo_violations.map do |v|
          "#{v[:file]}: #{v[:pattern]} - #{v[:suggestion]}"
        end

        expect(turbo_violations).to be_empty, "Turbo Frames and turbo_stream_from are not allowed:\n#{error_details.join("\n")}"
      end
    end
  end

  describe 'ActionCable Broadcast Type Validation' do
    it 'validates that broadcast types match frontend handlers' do
      broadcast_errors = []

      # Check channel files and job files
      source_files = Dir.glob(Rails.root.join('app/channels/**/*_channel.rb')) +
                     Dir.glob(Rails.root.join('app/jobs/**/*.rb'))

      source_files.each do |source_file|
        content = File.read(source_file)
        relative_path = source_file.sub(Rails.root.to_s + '/', '')

        # Skip ApplicationCable::Channel
        next if relative_path.include?('application_cable/channel.rb')

        # Parse file with AST
        begin
          ast = Parser::CurrentRuby.parse(content)
        rescue Parser::SyntaxError
          next # Skip files with syntax errors
        end

        # Find all ActionCable.server.broadcast calls using AST
        broadcasts = find_actioncable_broadcasts_in_ast(ast)

        broadcasts.each do |broadcast|
          type_value = broadcast[:type]
          stream_name = broadcast[:stream_name]
          line_number = broadcast[:line]

          # Infer channel name from stream name
          next unless stream_name

          channel_name = infer_channel_name_from_stream(stream_name)

          next unless channel_name

          controller_name = channel_name.dasherize
          frontend_controller_file = Rails.root.join("app/javascript/controllers/#{channel_name}_controller.ts")

          # Check if frontend controller exists
          unless File.exist?(frontend_controller_file)
            broadcast_errors << {
              source_file: relative_path,
              line: line_number,
              stream_name: stream_name,
              channel_name: channel_name,
              type: type_value,
              expected_method: type_value ? "handle#{capitalize_type(type_value)}" : nil,
              frontend_file: "app/javascript/controllers/#{channel_name}_controller.ts",
              error_type: 'missing_frontend_file',
              suggestion: "Create frontend controller (refer to existing *_controller.ts files for examples)"
            }
            next
          end

          if type_value.nil?
            # No type field found
            broadcast_errors << {
              source_file: relative_path,
              line: line_number,
              stream_name: stream_name,
              channel_name: channel_name,
              type: nil,
              expected_method: nil,
              frontend_file: "app/javascript/controllers/#{channel_name}_controller.ts",
              error_type: 'missing_type',
              suggestion: "Add 'type' field to broadcast hash: { type: 'your-type', ... }"
            }
          else
            # Convert type to method name (e.g., 'new-message' -> 'handleNewMessage')
            method_name = "handle#{capitalize_type(type_value)}"

            # Check if frontend controller has this method
            frontend_methods = controller_data[controller_name]&.fetch(:methods, []) || []

            # Strict match: method name must exactly match
            unless frontend_methods.include?(method_name)
              broadcast_errors << {
                source_file: relative_path,
                line: line_number,
                stream_name: stream_name,
                channel_name: channel_name,
                type: type_value,
                expected_method: method_name,
                frontend_file: "app/javascript/controllers/#{channel_name}_controller.ts",
                error_type: 'missing_handler',
                suggestion: "Add method to frontend controller: protected #{method_name}(data: any): void { ... }"
              }
            end
          end
        end
      end

      if broadcast_errors.any?
        puts "\n❌ ActionCable Broadcast Type Violations (#{broadcast_errors.length}):"

        missing_frontend_errors = broadcast_errors.select { |e| e[:error_type] == 'missing_frontend_file' }
        missing_type_errors = broadcast_errors.select { |e| e[:error_type] == 'missing_type' }
        missing_handler_errors = broadcast_errors.select { |e| e[:error_type] == 'missing_handler' }

        if missing_frontend_errors.any?
          puts "\n   📁 Missing frontend controller (#{missing_frontend_errors.length}):"
          missing_frontend_errors.each do |error|
            puts "     • #{error[:source_file]}:#{error[:line]}"
            puts "       Stream: '#{error[:stream_name]}' → expects #{error[:frontend_file]}"
            puts "       ✅ Fix: #{error[:suggestion]}"
          end
        end

        if missing_type_errors.any?
          puts "\n   📨 Missing 'type' field (#{missing_type_errors.length}):"
          missing_type_errors.each do |error|
            puts "     • #{error[:source_file]}:#{error[:line]}"
            puts "       Stream: '#{error[:stream_name]}'"
            puts "       ✅ Fix: #{error[:suggestion]}"
          end
        end

        if missing_handler_errors.any?
          puts "\n   🔌 Missing frontend handlers (#{missing_handler_errors.length}):"
          missing_handler_errors.each do |error|
            puts "     • #{error[:source_file]}:#{error[:line]}"
            puts "       Stream: '#{error[:stream_name]}', type: '#{error[:type]}' → expects #{error[:expected_method]}()"
            puts "       Frontend: #{error[:frontend_file]}"
            puts "       ✅ Fix: #{error[:suggestion]}"
          end
        end

        error_details = broadcast_errors.map do |e|
          case e[:error_type]
          when 'missing_frontend_file'
            "#{e[:source_file]}:#{e[:line]} - stream '#{e[:stream_name]}' needs #{e[:frontend_file]}"
          when 'missing_type'
            "#{e[:source_file]}:#{e[:line]} - stream '#{e[:stream_name]}' broadcast missing 'type' field"
          when 'missing_handler'
            "#{e[:source_file]}:#{e[:line]} - stream '#{e[:stream_name]}' type '#{e[:type]}' needs #{e[:expected_method]}() in #{e[:frontend_file]}"
          end
        end

        expect(broadcast_errors).to be_empty,
          "ActionCable broadcast validation failed:\n#{error_details.join("\n")}"
      end
    end
  end

  describe 'Turbo Stream Architecture Enforcement' do
    it 'validates frontend-backend interactions use Turbo Streams exclusively' do
      violations = []

      # Check backend controllers
      controller_files = Dir.glob(Rails.root.join('app/controllers/**/*_controller.rb'))

      controller_files.each do |file|
        content = File.read(file)
        relative_path = file.sub(Rails.root.to_s + '/', '')

        # Skip API namespace (explicit API endpoints can use JSON)
        next if relative_path.include?('app/controllers/api/')

        # Parse controller file with AST to find webhook/callback methods
        exempt_method_ranges = []
        begin
          ast = Parser::CurrentRuby.parse(content)
          find_exempt_methods(ast, content, exempt_method_ranges)
        rescue Parser::SyntaxError
          # If parsing fails, skip AST-based exemption (fall back to line-by-line)
        end

        lines = content.split("\n")

        lines.each_with_index do |line, index|
          line_number = index + 1
          stripped = line.strip

          # Skip JSON checks if current line is inside a webhook/callback method
          next if exempt_method_ranges.any? { |range| range.cover?(line_number) }

          # Detect head :ok / head :no_content
          if stripped.match?(/\bhead\s+:(ok|no_content)\b/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'head :ok',
              issue: 'Lacks explicit frontend interaction feedback',
              suggestion: 'Use Turbo Stream to provide specific UI update instructions'
            }
          end

          # Detect render json:
          if stripped.match?(/\brender\s+json:/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'render json:',
              issue: 'JSON response requires manual frontend data handling and DOM updates',
              suggestion: 'Use Turbo Stream for server-rendered HTML fragments'
            }
          end

          # Detect respond_to usage (forbidden)
          if stripped.match?(/\brespond_to\s+(do\b|\{)/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'respond_to',
              issue: 'respond_to block adds unnecessary complexity and branching logic',
              suggestion: 'Remove respond_to - use direct Turbo Stream rendering or HTML only'
            }
          end

          # Detect any format.* usage (forbidden)
          if stripped.match?(/\bformat\.\w+/)
            violations << {
              file: relative_path,
              line: line_number,
              code: stripped,
              type: 'format.*',
              issue: 'Format-based response handling adds complexity and violates Turbo Stream architecture',
              suggestion: 'Remove format blocks - render Turbo Streams directly or HTML templates only'
            }
          end

          # Detect implicit redirect_to @model (must use explicit path helpers)
          if stripped.match?(/\bredirect_to\s+@\w+/)
            # Exclude if already using path helper: redirect_to xxx_path(@model)
            unless stripped.match?(/\bredirect_to\s+\w+_(path|url)\(/)
              # Extract the instance variable name for better suggestion
              var_match = stripped.match(/\bredirect_to\s+(@\w+)/)
              var_name = var_match ? var_match[1] : '@resource'
              resource_name = var_name.gsub('@', '')

              violations << {
                file: relative_path,
                line: line_number,
                code: stripped,
                type: 'redirect_to @model',
                issue: 'Implicit route for redirect_to makes code less readable and harder to refactor',
                suggestion: "Use explicit route helper: redirect_to #{resource_name}_path(#{var_name}) instead of redirect_to #{var_name}"
              }
            end
          end
        end
      end

      # Check frontend Stimulus controllers for anti-patterns
      controller_data.each do |controller_name, data|
        file = data[:file]
        relative_path = file.sub(Rails.root.to_s + '/', '')

        # Skip image_upload_controller.ts (designed for API endpoint interaction)
        next if relative_path.include?('image_upload_controller.ts')

        # Check for preventDefault + requestSubmit anti-pattern (from parser)
        data[:anti_patterns].each do |pattern|
          violations << {
            file: relative_path,
            line: pattern['line'],
            code: "#{pattern['method']}()",
            type: pattern['type'],
            issue: pattern['issue'],
            suggestion: "In #{pattern['method']}(): Remove preventDefault() if you want the form to submit"
          }
        end

        # Check for fetch() calls (simple regex check)
        content = File.read(file)
        lines = content.split("\n")
        lines.each_with_index do |line, index|
          line_number = index + 1

          if line.match?(/\bfetch\s*\(/)
            violations << {
              file: relative_path,
              line: line_number,
              code: line.strip,
              type: 'fetch()',
              issue: 'Using fetch() breaks Turbo Stream architecture and requires manual response handling',
              suggestion: 'Use standard form submission to let Turbo handle the interaction'
            }
          end
        end
      end

      if violations.any?
        puts "\n❌ Frontend-Backend Architecture Violations (#{violations.length} violation(s) found):"
        puts "   📋 Architecture: Use HTML, use Turbo Stream for partial DOM updates when needed"
        puts "   🎯 Goal: Reduce frontend complexity and avoid manual DOM manipulation errors\n"

        violations.group_by { |v| v[:file] }.each do |file, file_violations|
          puts "   📄 #{file}:"
          file_violations.each do |v|
            puts "      Line #{v[:line]}: #{v[:code]}"
            puts "      ❌ Problem: #{v[:issue]}"
            puts "      ✅ Fix: #{v[:suggestion]}\n"
          end
        end

        puts "   ℹ️  Why this matters:"
        puts "      • respond_to blocks add unnecessary complexity and branching logic"
        puts "      • format.* methods violate our simplified architecture (use direct rendering instead)"
        puts "      • head :ok only returns status code, frontend cannot determine what to update"
        puts "      • JSON responses require manual DOM updates, easy to miss related elements (e.g. counters)"
        puts "      • Manual form submission (requestSubmit) bypasses Turbo's automatic handling"
        puts "      • Implicit redirect_to @model makes code less searchable and harder to refactor routes"
        puts "      • Turbo Stream (action.turbo_stream.erb) lets backend control UI updates precisely"
        puts "      • API endpoints (app/controllers/api/) are exempt from this requirement\n"

        error_details = violations.map do |v|
          "#{v[:file]}:#{v[:line]} - #{v[:type]}: #{v[:issue]}"
        end

        expect(violations).to be_empty,
          "Frontend-backend interactions must use Turbo Stream architecture:\n#{error_details.join("\n")}"
      end
    end
  end
end
