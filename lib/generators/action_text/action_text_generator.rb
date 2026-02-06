class ActionTextGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc 'Install ActionText with Tailwind CSS and TypeScript support'

  def check_dependencies
    unless gem_installed?('image_processing')
      say "⚠️  Warning: image_processing gem not found", :yellow
      say "💡 Add to Gemfile: gem 'image_processing', '~> 1.2'", :blue
      say "   Then run: bundle install", :blue
    end
  end

  def create_migration
    say "Creating ActionText tables migration...", :green

    timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
    migration_file = "db/migrate/#{timestamp}_create_action_text_tables.rb"

    template 'create_action_text_tables.rb.erb', migration_file

    say "✓ Migration created: #{migration_file}", :green
  end

  def install_trix_package
    say "Installing trix via npm...", :green
    run "npm install trix@^2.0.0"
    say "✓ Trix package installed", :green
  end

  def create_trix_controller
    say "Creating Trix Stimulus controller...", :green
    template 'trix_editor_controller.ts.erb', 'app/javascript/controllers/trix_editor_controller.ts'

    insert_into_index_ts
    say "✓ Trix controller created", :green
  end

  def create_trix_toolbar
    say "Creating Trix toolbar customization...", :green
    template 'trix_toolbar.ts.erb', 'app/javascript/trix_toolbar.ts'
    say "✓ Trix toolbar created", :green
  end

  def create_actiontext_stylesheet
    say "Creating ActionText Tailwind stylesheet...", :green
    template 'actiontext.css.erb', 'app/assets/stylesheets/actiontext.css'

    insert_into_application_css
    say "✓ ActionText stylesheet created", :green
  end

  def import_trix_toolbar_in_base_ts
    say "Adding Trix toolbar import to base.ts...", :green

    base_ts = 'app/javascript/base.ts'

    unless File.exist?(base_ts)
      say "⚠️  base.ts not found", :yellow
      say "💡 Make sure you have app/javascript/base.ts in your project", :blue
      return
    end

    content = File.read(base_ts)
    if content.include?("import './trix_toolbar'")
      say "⚠️  Trix toolbar import already exists in base.ts", :yellow
      return
    end

    insert_after_last_import(base_ts, "import './trix_toolbar'\n")
    say "✓ Added Trix toolbar import to base.ts", :green
  end

  def create_blob_partial
    say "Creating ActiveStorage blob partial...", :green

    directory = 'app/views/active_storage/blobs'
    FileUtils.mkdir_p(directory) unless File.directory?(directory)

    template 'blob.html.erb', "#{directory}/_blob.html.erb"
    say "✓ Blob partial created", :green
  end

  def display_post_install_message
    say "\n"
    say "=" * 70, :green
    say "✅ ActionText installed successfully!", :green
    say "=" * 70, :green
    say "\n"
    say "Next Steps:", :blue
    say "\n"
    say "Run migrations:", :cyan
    say "  bin/rails db:migrate", :white
    say "\n"
    say "Add to your model:", :cyan
    say "  class Post < ApplicationRecord", :white
    say "    has_rich_text :content", :yellow
    say "  end", :white
    say "\n"
    say "Use in your form:", :cyan
    say "  <%= form.rich_text_area :content,", :white
    say "      data: { controller: 'trix-editor' },", :white
    say "      class: 'trix-content' %>", :white
    say "\n"
    say "Display content:", :cyan
    say "  <div class='prose'>", :white
    say "    <%= @post.content %>", :yellow
    say "  </div>", :white
    say "\n"
    say "Features:", :magenta
    say "  • Trix rich text editor with Tailwind styling", :white
    say "  • File uploads via ActiveStorage with progress", :white
    say "  • File size validation (10MB limit)", :white
    say "  • Link dialog support", :white
    say "  • Dark mode support", :white
    say "\n"
  end

  private

  def gem_installed?(gem_name)
    Gem::Specification.find_by_name(gem_name)
    true
  rescue Gem::MissingSpecError
    false
  end

  # Insert content after the last import statement in a TS/JS file
  # Falls back to prepending if no imports found
  def insert_after_last_import(file_path, content_to_insert)
    return false unless File.exist?(file_path)

    file_content = File.read(file_path)
    lines = file_content.lines
    last_import_index = nil

    lines.each_with_index do |line, index|
      last_import_index = index if line =~ /^import\s+/
    end

    if last_import_index
      lines.insert(last_import_index + 1, content_to_insert)
      File.write(file_path, lines.join)
      true
    else
      prepend_to_file file_path, content_to_insert
      true
    end
  end

  # Insert @import after the first @import in CSS
  # Falls back to inserting before @tailwind/@layer, or at the beginning
  def insert_after_first_css_import(file_path, import_statement)
    return false unless File.exist?(file_path)

    file_content = File.read(file_path)
    lines = file_content.lines
    first_import_index = nil
    first_tailwind_index = nil

    lines.each_with_index do |line, index|
      if line =~ /@import\s+/
        first_import_index = index
        break
      end
    end

    if first_import_index
      # Insert after the first @import
      lines.insert(first_import_index + 1, "#{import_statement}\n")
      File.write(file_path, lines.join)
      :after_import
    else
      # Find first @tailwind or @layer
      lines.each_with_index do |line, index|
        if line =~ /^(@tailwind|@layer)/
          first_tailwind_index = index
          break
        end
      end

      if first_tailwind_index
        # Insert before @tailwind/@layer
        lines.insert(first_tailwind_index, "#{import_statement}\n")
        File.write(file_path, lines.join)
        :before_tailwind
      else
        # Insert at the beginning
        prepend_to_file file_path, "#{import_statement}\n"
        :at_beginning
      end
    end
  end

  def insert_into_index_ts
    index_path = "app/javascript/controllers/index.ts"
    return unless File.exist?(index_path)

    import_line = "import TrixEditorController from \"./trix_editor_controller\""
    register_line = "application.register(\"trix-editor\", TrixEditorController)"

    content = File.read(index_path)

    return if content.include?("trix_editor_controller") || content.include?("trix-editor")

    inject_into_file index_path, "#{import_line}\n", after: /import.*_controller"\n(?=\n)/
    inject_into_file index_path, "#{register_line}\n", after: /application\.register\(.*\)\n(?=\n)/
  end

  def insert_into_application_css
    say "Adding ActionText CSS import...", :green

    css_path = "app/assets/stylesheets/application.css"

    unless File.exist?(css_path)
      say "⚠️  application.css not found", :yellow
      return
    end

    import_line = "@import './actiontext.css';"
    content = File.read(css_path)

    if content.include?('actiontext.css')
      say "⚠️  ActionText CSS import already exists", :yellow
      return
    end

    result = insert_after_first_css_import(css_path, import_line)

    case result
    when :after_import
      say "✓ Added ActionText CSS import after first @import", :green
    when :before_tailwind
      say "✓ Added ActionText CSS import before @tailwind", :green
    when :at_beginning
      say "✓ Added ActionText CSS import at the beginning", :green
    end
  end
end
