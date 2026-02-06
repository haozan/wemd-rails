module LintHelper
  module_function

  LINT_MARKER = "tmp/lint_executed"

  def needs_lint?
    lintable_files = Dir.glob("app/javascript/**/*.{js,ts,tsx}") +
                     Dir.glob("spec/javascript/**/*.{js,ts}")

    return true if lintable_files.empty?
    return true unless File.exist?(LINT_MARKER)

    latest_source = lintable_files.map { |f| File.mtime(f) }.max
    marker_time = File.mtime(LINT_MARKER)

    latest_source > marker_time
  end

  def mark_lint_success
    FileUtils.mkdir_p('tmp')
    FileUtils.touch(LINT_MARKER)
  end
end
