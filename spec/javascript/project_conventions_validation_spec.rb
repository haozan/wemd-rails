require 'rails_helper'

RSpec.describe 'Project Conventions Validation', type: :system do
  # Initialize pipeline once for all tests
  let(:pipeline) { StimulusValidationPipeline.new }
  let(:view_files) { pipeline.view_files }

  # Helper method for finding model creations in AST
  def find_model_creations_in_ast(node, results = {})
    return results unless node

    if node.type == :send
      receiver = node.children[0]
      method = node.children[1]

      # Match Model.create / Model.create!
      if receiver && receiver.type == :const && [:create, :create!].include?(method)
        model_name = receiver.children[1].to_s

        # Extract hash parameters (handles both direct hash and array of hashes)
        params = []
        node.children[2..-1].each do |arg|
          next unless arg.is_a?(Parser::AST::Node)

          # Handle direct hash argument: Model.create!({...})
          if arg.type == :hash
            arg.children.each do |pair|
              if pair.type == :pair
                key = pair.children[0]
                param_name = key.type == :sym ? key.children[0].to_s : key.children[0]
                params << param_name
              end
            end
          # Handle array of hashes: Model.create!([{...}, {...}])
          elsif arg.type == :array
            arg.children.each do |array_element|
              if array_element.is_a?(Parser::AST::Node) && array_element.type == :hash
                array_element.children.each do |pair|
                  if pair.type == :pair
                    key = pair.children[0]
                    param_name = key.type == :sym ? key.children[0].to_s : key.children[0]
                    params << param_name
                  end
                end
              end
            end
          end
        end

        results[model_name] ||= []
        results[model_name] << {
          line: node.loc.line,
          params: params
        }
      end
    end

    # Recursively search child nodes
    if node.respond_to?(:children)
      node.children.each do |child|
        find_model_creations_in_ast(child, results) if child.is_a?(Parser::AST::Node)
      end
    end

    results
  end

  describe 'Routes Validation' do
    it 'ensures routes.rb does not use custom param option' do
      param_violations = []
      routes_file = Rails.root.join('config/routes.rb')

      return unless File.exist?(routes_file)

      content = File.read(routes_file)
      lines = content.lines

      lines.each_with_index do |line, index|
        line_number = index + 1

        # Skip comments
        next if line.strip.start_with?('#')

        # Check for param: usage in routes
        if line.match?(/\bparam:\s*:/)
          param_violations << {
            line: line_number,
            content: line.strip,
            suggestion: "Do not use 'param:' to customize route parameter. Use friendly_id (already configured) for slug customization instead."
          }
        end
      end

      if param_violations.any?
        puts "\n⚠️  Routes param: violations (#{param_violations.length}):"
        param_violations.each do |v|
          puts "   Line #{v[:line]}: #{v[:content]}"
          puts "   💡 #{v[:suggestion]}\n"
        end

        error_details = param_violations.map do |v|
          "config/routes.rb:#{v[:line]} - #{v[:suggestion]}"
        end

        expect(param_violations).to be_empty,
          "Routes validation failed:\n#{error_details.join("\n")}"
      else
      end
    end
  end

  describe 'ActiveStorage Seed Image Validation' do
    it 'validates that seed file attaches images for models being created' do
      missing_attachments = []
      seed_file = Rails.root.join('db/seeds.rb')

      unless File.exist?(seed_file)
        puts "\n⚠️  Skipping ActiveStorage seed validation: db/seeds.rb not found"
        next
      end

      seed_content = File.read(seed_file)

      begin
        ast = Parser::CurrentRuby.parse(seed_content)
      rescue Parser::SyntaxError
        puts "\n⚠️  Skipping ActiveStorage seed validation: db/seeds.rb has syntax errors"
        next
      end

      # Ensure all models are loaded
      Rails.application.eager_load! unless Rails.application.config.eager_load

      # Find all Model.create! / Model.create calls in seed file
      model_creations = find_model_creations_in_ast(ast)

      # Check each model that has image attachments
      ApplicationRecord.descendants.each do |model|
        next if model.abstract_class? || model.attachment_reflections.empty?

        model_name = model.name

        # Check if this model is being created in seed
        creations = model_creations[model_name]
        next unless creations && creations.any?

        # Get image attachments for this model
        image_attachments = model.attachment_reflections.select do |name, _|
          name.to_s.match?(/image|photo|picture|avatar|cover|banner|logo|thumbnail|icon|gallery/) &&
          !name.to_s.match?(/document|file|pdf|resume|cv|report/)
        end

        next if image_attachments.empty?

        # Check each creation
        creations.each do |creation|
          image_attachments.each do |attachment_name, reflection|
            unless creation[:params].include?(attachment_name.to_s)
              missing_attachments << {
                model: model_name,
                attachment: attachment_name,
                type: reflection.macro.to_s.gsub('has_', '').gsub('_attached', ''),
                line: creation[:line]
              }
            end
          end
        end
      end

      if missing_attachments.any?
        puts "\n❌ ActiveStorage Seed Errors (#{missing_attachments.length}):"
        missing_attachments.group_by { |e| e[:model] }.each do |model, errors|
          puts "   📦 #{model}:"
          errors.each do |e|
            puts "      • Line #{e[:line]}: missing #{e[:attachment]} (#{e[:type]})"
          end
        end

        puts "\n   💡 Fix:"
        missing_attachments.group_by { |e| e[:model] }.each do |model, errors|
          puts "      #{model}.create!("
          errors.uniq { |e| e[:attachment] }.each do |e|
            url_example = e[:type] == 'one' ?
              "{ io: URI.open('https://picsum.photos/800'), filename: 'photo.jpg' }" :
              "[{ io: URI.open('https://picsum.photos/800'), filename: 'photo.jpg' }]"
            puts "        #{e[:attachment]}: #{url_example},"
          end
          puts "      )"
        end

        expect(missing_attachments).to be_empty,
          "Seed must attach images: #{missing_attachments.map { |e| "#{e[:model]}##{e[:attachment]}" }.uniq.join(', ')}"
      else
      end
    end
  end

  describe 'CSS Import Order Validation' do
    it 'ensures @import statements appear before @tailwind directives' do
      css_violations = []
      css_file = Rails.root.join('app/assets/stylesheets/application.css')

      unless File.exist?(css_file)
        puts "\n⚠️  Skipping CSS import validation: application.css not found"
        next
      end

      content = File.read(css_file)
      lines = content.split("\n")

      first_tailwind_line = nil
      import_violations = []

      lines.each_with_index do |line, index|
        line_number = index + 1
        stripped = line.strip

        # Skip comments
        next if stripped.start_with?('/*') || stripped.start_with?('//')

        # Track first @tailwind directive
        if stripped.match?(/^@tailwind\s/)
          first_tailwind_line ||= line_number
        end

        # Check for @import after @tailwind
        if stripped.match?(/^@import\s/)
          if first_tailwind_line && line_number > first_tailwind_line
            import_violations << {
              line: line_number,
              content: stripped,
              first_tailwind_line: first_tailwind_line
            }
          end
        end
      end

      if import_violations.any?
        puts "\n❌ CSS Import Order Errors (#{import_violations.length}):"
        import_violations.each do |v|
          puts "   Line #{v[:line]}: #{v[:content]}"
          puts "   ⚠️  @import appears AFTER @tailwind (line #{v[:first_tailwind_line]})"
        end

        puts "\n   💡 Why this is wrong:"
        puts "      • CSS spec requires @import to be at the top of the file"
        puts "      • Browsers and build tools will ignore @import statements after other rules"
        puts "      • This causes your imported styles (e.g., components.css) to not load"
        puts "\n   ✅ Correct order:"
        puts "      1. @import statements (MUST be first)"
        puts "      2. @tailwind directives"
        puts "      3. Other CSS rules\n"

        error_details = import_violations.map { |v| "Line #{v[:line]}: @import after @tailwind" }
        expect(import_violations).to be_empty,
          "CSS import validation failed:\n#{error_details.join("\n")}"
      else
      end
    end
  end

  describe 'Image Processing Library Validation' do
    it 'enforces Vips-only image processing (no ImageMagick/MiniMagick)' do
      violations = []

      # Define file patterns to scan (minimal necessary set)
      scan_patterns = [
        'app/models/**/*.rb',           # Models with image attachments
        'app/uploaders/**/*.rb',        # CarrierWave uploaders (if exists)
        'app/services/**/*image*.rb',   # Image processing services
        'app/services/**/*photo*.rb',   # Photo processing services
        'app/jobs/**/*image*.rb',       # Image processing jobs
        'app/jobs/**/*photo*.rb',       # Photo processing jobs
        'config/initializers/**/*.rb'   # ActiveStorage config
      ]

      # Collect files to scan
      files_to_scan = []
      scan_patterns.each do |pattern|
        files_to_scan.concat(Dir.glob(Rails.root.join(pattern)))
      end

      # Forbidden patterns (ImageMagick/MiniMagick/direct Vips)
      forbidden_patterns = [
        { pattern: /\bMiniMagick::Image\b/, name: 'MiniMagick::Image', reason: 'Use ImageProcessing::Vips instead' },
        { pattern: /\bMiniMagick::Tool\b/, name: 'MiniMagick::Tool', reason: 'Use ImageProcessing::Vips instead' },
        { pattern: /\bImageMagick::\b/, name: 'ImageMagick::', reason: 'Use ImageProcessing::Vips instead' },
        { pattern: /\bImageList\.new\b/, name: 'ImageList.new (RMagick)', reason: 'Use ImageProcessing::Vips instead' },
        { pattern: /\bVips::Image\b/, name: 'Vips::Image (direct)', reason: 'Use ImageProcessing::Vips wrapper instead' },
        { pattern: /\bImageProcessing::MiniMagick\b/, name: 'ImageProcessing::MiniMagick', reason: 'Use ImageProcessing::Vips (Vips-only policy)' }
      ]

      files_to_scan.each do |file|
        content = File.read(file)
        relative_path = file.sub(Rails.root.to_s + '/', '')
        lines = content.split("\n")

        lines.each_with_index do |line, index|
          line_number = index + 1
          stripped = line.strip

          # Skip comments
          next if stripped.start_with?('#')

          # Allow ImageProcessing::Vips (correct usage)
          next if line.match?(/\bImageProcessing::Vips\b/)

          # Check for forbidden patterns
          forbidden_patterns.each do |forbidden|
            if line.match?(forbidden[:pattern])
              violations << {
                file: relative_path,
                line: line_number,
                code: stripped,
                forbidden: forbidden[:name],
                reason: forbidden[:reason]
              }
            end
          end
        end
      end

      if violations.any?
        puts "\n❌ Image Processing Policy Violations (#{violations.length}):"
        puts "   📋 Policy: Use Vips only (via ImageProcessing::Vips)\n"

        violations.group_by { |v| v[:forbidden] }.each do |pattern, pattern_violations|
          puts "\n   🚫 Found #{pattern} (#{pattern_violations.length}):"
          pattern_violations.each do |v|
            puts "     • #{v[:file]}:#{v[:line]}"
            puts "       #{v[:code]}"
          end
        end

        puts "\n   💡 Why Vips-only?"
        puts "      • Vips is 4-10x faster than ImageMagick/MiniMagick"
        puts "      • Lower memory usage (streaming processing)"
        puts "      • Better for production workloads"
        puts "      • Simpler dependency management (one library)"

        puts "\n   ✅ Correct usage (Vips via ImageProcessing):"
        puts "      # Basic processing:"
        puts "      ImageProcessing::Vips"
        puts "        .source(file)"
        puts "        .resize_to_limit(800, 600)"
        puts "        .convert('jpg')"
        puts "        .call"
        puts ""
        puts "      # ActiveStorage variants:"
        puts "      class User < ApplicationRecord"
        puts "        has_one_attached :avatar do |attachable|"
        puts "          attachable.variant :thumb, resize_to_limit: [100, 100]"
        puts "          attachable.variant :medium, resize_to_limit: [400, 400]"
        puts "        end"
        puts "      end"
        puts ""
        puts "      # Note: ActiveStorage automatically uses ImageProcessing::Vips"
        puts "      # if 'image_processing' gem is installed and vips is available\n"

        error_details = violations.map do |v|
          "#{v[:file]}:#{v[:line]} - #{v[:forbidden]} (#{v[:reason]})"
        end

        expect(violations).to be_empty,
          "Vips-only policy violated:\n#{error_details.join("\n")}"
      else
      end
    end
  end

  describe 'View Helper Method Definition Validation' do
    it 'prohibits defining helper methods in views via content_for' do
      violations = []
      allowed_content_for = %w[title head]

      view_files.each do |file|
        content = File.read(file)
        relative_path = file.sub(Rails.root.to_s + '/', '')
        lines = content.split("\n")

        lines.each_with_index do |line, index|
          line_number = index + 1
          if match = line.strip.match(/content_for\s+:(\w+)/)
            key = match[1]
            unless allowed_content_for.include?(key)
              violations << {
                file: relative_path,
                line: line_number,
                type: "content_for :#{key}"
              }
            end
          end
        end
      end

      if violations.any?
        puts "\n❌ View Helper Violations (#{violations.length}):"
        violations.each { |v| puts "   #{v[:file]}:#{v[:line]} - #{v[:type]}" }
        puts "\n   ✅ Fix: Define helpers in app/helpers/application_helper.rb\n"
        expect(violations).to be_empty
      end
    end
  end
end
