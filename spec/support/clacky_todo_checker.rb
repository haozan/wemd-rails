# Shared helper for checking CLACKY_TODO comments in generated code
# This ensures developers implement required functionality before deploying
module ClackyTodoChecker
  # Check if any CLACKY_TODO comments exist in the specified files
  # @param files [Array<String>] Array of file paths relative to Rails.root
  # @return [void] Fails the test if TODOs are found
  def check_clacky_todos(files)
    todos_found = []

    files.each do |file_path|
      full_path = Rails.root.join(file_path)
      next unless File.exist?(full_path)

      content = File.read(full_path)
      lines = content.lines

      # Extract CLACKY_TODO and its description with context
      lines.each_with_index do |line, index|
        if line =~ /CLACKY_TODO:\s*(.+)/
          description = $1.strip

          # Get the next 3 lines as hints
          hints = []
          (1..3).each do |offset|
            next_line = lines[index + offset]
            break if next_line.nil?
            hints << next_line.rstrip
          end

          todos_found << {
            file: file_path,
            description: description,
            hints: hints
          }
        end
      end
    end

    return if todos_found.empty?

    error_message = "\n❌ Found #{todos_found.length} unresolved CLACKY_TODO(s):\n\n"

    todos_found.each do |todo|
      error_message += "📄 #{todo[:file]}\n"
      error_message += "   TODO: #{todo[:description]}\n"

      unless todo[:hints].empty?
        error_message += "   Hints:\n"
        todo[:hints].each do |hint|
          error_message += "   #{hint}\n"
        end
      end

      error_message += "\n"
    end

    error_message += "Please implement the required functionality and remove CLACKY_TODO comments.\n"

    fail error_message
  end
end

RSpec.configure do |config|
  config.include ClackyTodoChecker
end
