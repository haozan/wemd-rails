module AssetHelper
  module_function

  def needs_compilation?
    js_files = Dir.glob("app/javascript/**/*.{js,ts,tsx}")
    css_files = Dir.glob("app/assets/stylesheets/**/*.css")

    # Check if build output directory exists
    return true unless Dir.exist?("app/assets/builds")

    # Only check actual compiled output files at root level (.js and .css)
    built_files = Dir.glob("app/assets/builds/*.{js,css}")
                     .select { |f| File.file?(f) }

    return true if built_files.empty?

    # Compare source files modification time with built files
    source_files = js_files + css_files
    return true if source_files.empty?

    latest_source = source_files.map { |f| File.mtime(f) }.max
    latest_built = built_files.map { |f| File.mtime(f) }.max

    # If any source file is newer than the latest built file, need recompilation
    latest_source > latest_built
  end
end
