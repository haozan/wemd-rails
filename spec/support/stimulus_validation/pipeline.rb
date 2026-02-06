# StimulusValidationPipeline - Centralized file scanning and caching for Stimulus validation
#
# This pipeline scans controller and view files once and caches the results,
# eliminating redundant file scanning across multiple test cases.
class StimulusValidationPipeline
  attr_reader :controller_data, :view_files, :partial_parent_map

  @instance = nil

  def self.new
    @instance ||= super
  end

  def initialize
    @controllers_dir = Rails.root.join('app/javascript/controllers')
    @views_dir = Rails.root.join('app/views')

    # Scan and cache all data upfront
    @controller_data = scan_controllers
    @view_files = scan_view_files
    @partial_parent_map = build_partial_parent_map
  end

  # Get controllers from parent files (recursive) with memoization
  def get_controllers_from_parents(partial_path)
    @parent_controllers_cache ||= {}
    return @parent_controllers_cache[partial_path] if @parent_controllers_cache.key?(partial_path)

    controllers = []

    parent_files = partial_parent_map[partial_path] || []
    parent_files.each do |parent_file|
      parent_content = File.read(Rails.root.join(parent_file))
      parent_doc = Nokogiri::HTML::DocumentFragment.parse(parent_content)

      parent_doc.css('[data-controller]').each do |element|
        element['data-controller'].split(/\s+/).each do |controller|
          controllers << controller.strip
        end
      end

      if parent_file.include?('_')
        controllers.concat(get_controllers_from_parents(parent_file))
      end
    end

    @parent_controllers_cache[partial_path] = controllers.uniq
  end

  private

  # Scan all TypeScript controllers and parse their metadata
  def scan_controllers
    data = {}

    Dir.glob(@controllers_dir.join('*_controller.ts')).each do |file|
      controller_name = File.basename(file, '.ts').gsub('_controller', '').gsub('_', '-')

      # Use TypeScript AST parser to extract controller metadata
      parser_script = Rails.root.join('bin/parse_ts_controller.js')
      result_json = `node #{parser_script} #{file}`

      if $?.success?
        parsed_data = JSON.parse(result_json)

        data[controller_name] = {
          targets: parsed_data['targets'] || [],
          optional_targets: parsed_data['optionalTargets'] || [],
          outlets: parsed_data['outlets'] || [],
          values: parsed_data['values'] || [],
          values_with_defaults: parsed_data['valuesWithDefaults'] || [],
          methods: parsed_data['methods'] || [],
          querySelectors: parsed_data['querySelectors'] || [],
          anti_patterns: parsed_data['antiPatterns'] || [],
          targets_with_skip: parsed_data['targetsWithSkip'] || [],
          values_with_skip: parsed_data['valuesWithSkip'] || [],
          is_system_controller: parsed_data['isSystemController'] || false,
          file: file
        }
      else
        raise 'Parse ts controller failed'
      end
    end

    data
  end

  # Scan all view files with filtering
  def scan_view_files
    all_files = Dir.glob(@views_dir.join('**/*.html.erb'))

    if ENV['FULL_VIEW_DEBUG']
      all_files.reject { |file| file.include?('shared/demo.html.erb') }
    else
      all_files.reject do |file|
        file.include?('shared/demo.html.erb') ||
        file.include?('/admin/') ||
        file.include?('/kaminari/') ||
        file.include?('/shared/admin/') ||
        file.include?('shared/friendly_error.html.erb') ||
        file.include?('shared/missing_template_fallback.html.erb')
      end
    end
  end

  # Build a map of partial files to their parent files
  def build_partial_parent_map
    map = {}

    @view_files.each do |view_file|
      content = File.read(view_file)
      relative_path = view_file.sub(Rails.root.to_s + '/', '')

      content.scan(/render\s+(?:partial:\s*)?['"]([^'"]+)['"]/) do |match|
        partial_name = match[0]

        if partial_name.include?('/')
          # shared/admin/header -> app/views/shared/admin/_header.html.erb
          partial_path = "app/views/#{partial_name.gsub(/([^\/]+)$/, '_\1')}.html.erb"
        else
          # header -> app/views/current_dir/_header.html.erb
          current_dir = File.dirname(relative_path)
          partial_path = "#{current_dir}/_#{partial_name}.html.erb"
        end

        map[partial_path] ||= []
        map[partial_path] << relative_path
      end
    end

    map
  end
end
