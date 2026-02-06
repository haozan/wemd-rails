# LLM Service - Unified LLM API wrapper with Tool Call & MCP support
# Default streaming API with blocking fallback
# call(&block) - streaming by default, blocking if no block given
#
# Tool Call Support:
#   - Pass tools: [...] to enable function calling
#   - Pass tool_choice: 'auto'|'required'|{type: 'function', function: {name: 'foo'}}
#   - Pass tool_handler: ->(tool_name, args) { ... } to handle tool execution
#
# MCP Support:
#   - Pass mcp_server_url: 'http://...' to load tools from MCP server
#   - MCP tools are automatically converted to OpenAI function format
class LlmService < ApplicationService
  class LlmError < StandardError; end
  class TimeoutError < LlmError; end
  class ApiError < LlmError; end
  class ToolExecutionError < LlmError; end

  def initialize(prompt:, system: nil, **options)
    @prompt = prompt
    @system = system
    @options = options
    @model = options[:model] || ENV.fetch('LLM_MODEL')
    @temperature = options[:temperature]&.to_f || 0.7
    @max_tokens = options[:max_tokens] || 4000
    @timeout = options[:timeout] || 30
    @images = normalize_images(options[:images])

    # Tool call support
    @tools = options[:tools] || []
    @tool_choice = options[:tool_choice] # 'auto', 'required', 'none', or {type: 'function', function: {name: 'foo'}}
    @tool_handler = options[:tool_handler] # Proc to execute tools: ->(tool_name, args) { ... }
    @max_tool_iterations = options[:max_tool_iterations] || 5

    # MCP support
    @mcp_server_url = options[:mcp_server_url]
    load_mcp_tools if @mcp_server_url.present?

    # If MCP is used but no handler provided, use default MCP handler
    if @mcp_server_url.present? && @tool_handler.nil?
      @tool_handler = build_mcp_tool_handler
    end

    # Conversation history for multi-turn tool calls
    @messages = []
  end

  # Default call - streaming if block given, blocking otherwise
  def call(&block)
    if block_given?
      call_stream(&block)
    else
      call_blocking
    end
  end

  # Explicit blocking call (returns full response)
  # Automatically handles tool calls if tools are provided
  def call_blocking
    raise LlmError, "Prompt cannot be blank" if @prompt.blank?

    # Build initial messages
    build_initial_messages

    # If tools are available, use multi-turn loop to handle tool calls
    if @tools.present?
      call_blocking_with_tools
    else
      call_blocking_simple
    end
  rescue => e
    Rails.logger.error("LLM Error: #{e.class} - #{e.message}")
    raise
  end

  # Simple blocking call without tool support (backward compatible)
  def call_blocking_simple
    response = make_http_request(stream: false)
    content = response.dig("choices", 0, "message", "content")

    raise LlmError, "No content in response" if content.blank?

    content
  end

  # Blocking call with automatic tool execution
  def call_blocking_with_tools
    iteration = 0
    final_content = nil

    loop do
      iteration += 1
      raise LlmError, "Max tool iterations (#{@max_tool_iterations}) exceeded" if iteration > @max_tool_iterations

      response = make_http_request(stream: false)
      message = response.dig("choices", 0, "message")

      # Add assistant message to history
      @messages << message

      # Check if tool calls are requested
      tool_calls = message["tool_calls"]

      if tool_calls.present?
        # Execute tools and add results to messages
        handle_tool_calls(tool_calls)
      else
        # No more tool calls, return final content
        final_content = message["content"]
        break
      end
    end

    raise LlmError, "No content in final response" if final_content.blank?

    final_content
  end

  # Explicit streaming call (yields chunks as they arrive)
  # Supports tool calls in streaming mode
  def call_stream(&block)
    raise LlmError, "Prompt cannot be blank" if @prompt.blank?
    raise LlmError, "Block required for streaming" unless block_given?

    build_initial_messages

    if @tools.present?
      call_stream_with_tools(&block)
    else
      call_stream_simple(&block)
    end
  rescue => e
    Rails.logger.error("LLM Stream Error: #{e.class} - #{e.message}")
    raise
  end

  # Simple streaming without tools (backward compatible)
  def call_stream_simple(&block)
    full_content = ""

    make_http_request(stream: true) do |chunk_data|
      # Extract content from chunk_data (backward compatible)
      content = chunk_data.is_a?(Hash) ? chunk_data[:content] : chunk_data
      if content.present?
        full_content += content
        block.call(content)
      end
    end

    full_content
  end

  # Streaming with tool call support
  def call_stream_with_tools(&block)
    iteration = 0
    final_content = ""

    loop do
      iteration += 1
      raise LlmError, "Max tool iterations (#{@max_tool_iterations}) exceeded" if iteration > @max_tool_iterations

      tool_calls_buffer = {}
      content_buffer = ""
      has_tool_calls = false

      # Stream response and accumulate tool calls
      make_http_request(stream: true) do |chunk_data|
        # chunk_data includes both content and tool_call deltas
        if chunk_data[:content]
          content_buffer += chunk_data[:content]
          block.call(chunk_data[:content])
        end

        if chunk_data[:tool_calls]
          has_tool_calls = true
          # Accumulate tool call deltas
          chunk_data[:tool_calls].each do |tc|
            idx = tc["index"]
            tool_calls_buffer[idx] ||= {
              "id" => "",
              "type" => "function",
              "function" => {"name" => "", "arguments" => ""}
            }

            tool_calls_buffer[idx]["id"] = tc["id"] if tc["id"]
            if tc["function"]
              tool_calls_buffer[idx]["function"]["name"] += tc["function"]["name"].to_s
              tool_calls_buffer[idx]["function"]["arguments"] += tc["function"]["arguments"].to_s
            end
          end
        end
      end

      # Build complete message
      message = {"role" => "assistant"}
      message["content"] = content_buffer if content_buffer.present?
      if has_tool_calls
        message["tool_calls"] = tool_calls_buffer.values
      end

      @messages << message

      if has_tool_calls
        # Execute tools and continue loop
        handle_tool_calls(message["tool_calls"])
      else
        # No tool calls, we're done
        final_content = content_buffer
        break
      end
    end

    final_content
  end

  # Class method shortcuts
  class << self
    # Default: streaming if block, blocking otherwise
    def call(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call(&block)
    end

    # Explicit blocking call
    def call_blocking(prompt:, system: nil, **options)
      new(prompt: prompt, system: system, **options).call_blocking
    end

    # Explicit streaming call
    def call_stream(prompt:, system: nil, **options, &block)
      new(prompt: prompt, system: system, **options).call_stream(&block)
    end
  end

  private

  def make_http_request(stream: false, &block)
    # Auto-mock in test environment to avoid slow API calls
    return mock_http_response(stream: stream, &block) if Rails.env.test?

    require 'net/http'
    require 'uri'
    require 'json'

    http, request = prepare_http_request(stream)

    if stream
      handle_stream_response(http, request, &block)
    else
      handle_blocking_response(http, request)
    end
  rescue Net::ReadTimeout
    raise TimeoutError, "Request timed out after #{@timeout}s"
  end

  def prepare_http_request(stream)
    base_url = ENV.fetch('LLM_BASE_URL')
    uri = URI.parse("#{base_url}/chat/completions")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = @timeout
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{api_key}"

    body = build_request_body
    if stream
      request["Accept"] = "text/event-stream"
      body[:stream] = true
    end
    request.body = body.to_json

    [http, request]
  end

  def handle_blocking_response(http, request)
    response = http.request(request)

    case response.code.to_i
    when 200
      JSON.parse(response.body)
    when 429
      raise ApiError, "Rate limit exceeded"
    when 500..599
      raise ApiError, "Server error: #{response.code}"
    else
      raise ApiError, "API error: #{response.code} - #{response.body}"
    end
  rescue JSON::ParserError => e
    raise ApiError, "Invalid JSON response: #{e.message}"
  end

  def handle_stream_response(http, request, &block)
    http.request(request) do |response|
      unless response.code.to_i == 200
        raise ApiError, "API error: #{response.code} - #{response.body}"
      end

      buffer = ""
      response.read_body do |chunk|
        buffer += chunk

        while (line_end = buffer.index("\n"))
          line = buffer[0...line_end].strip
          buffer = buffer[(line_end + 1)..-1]

          next if line.empty?
          next unless line.start_with?("data: ")

          data = line[6..-1]
          next if data == "[DONE]"

          begin
            json = JSON.parse(data)
            delta = json.dig("choices", 0, "delta")

            next unless delta

            # Build chunk data with content and tool_calls
            chunk_data = {}

            if content = delta["content"]
              chunk_data[:content] = content
            end

            if tool_calls = delta["tool_calls"]
              chunk_data[:tool_calls] = tool_calls
            end

            block.call(chunk_data) if chunk_data.present?
          rescue JSON::ParserError => e
            Rails.logger.warn("Failed to parse SSE chunk: #{e.message}")
          end
        end
      end
    end
  end

  def build_request_body
    body = {
      model: @model,
      messages: @messages,
      temperature: @temperature,
      max_tokens: @max_tokens
    }

    # Add tools if available
    if @tools.present?
      body[:tools] = @tools
      body[:tool_choice] = @tool_choice if @tool_choice.present?
    end

    # Some providers require modalities when sending images
    body[:modalities] = ["text", "image"] if @images.present?

    body
  end

  # Build initial messages from prompt, system, and images
  def build_initial_messages
    return if @messages.present? # Already built

    @messages << { role: "system", content: @system } if @system.present?

    if @images.present?
      user_content = []
      user_content << { type: "text", text: @prompt.to_s }
      @images.each do |img|
        user_content << { type: "image_url", image_url: { url: img } }
      end
      @messages << { role: "user", content: user_content }
    else
      @messages << { role: "user", content: @prompt }
    end
  end

  # Handle tool calls by executing them and adding results to messages
  def handle_tool_calls(tool_calls)
    raise ToolExecutionError, "No tool_handler provided" unless @tool_handler

    tool_calls.each do |tool_call|
      tool_id = tool_call["id"]
      function_name = tool_call.dig("function", "name")
      arguments_json = tool_call.dig("function", "arguments")

      begin
        # Parse arguments
        arguments = JSON.parse(arguments_json)

        # Execute tool via handler
        result = @tool_handler.call(function_name, arguments)

        # Add tool result to messages
        @messages << {
          role: "tool",
          tool_call_id: tool_id,
          name: function_name,
          content: result.to_json
        }
      rescue => e
        # Add error as tool result
        @messages << {
          role: "tool",
          tool_call_id: tool_id,
          name: function_name,
          content: { error: e.message }.to_json
        }
        Rails.logger.error("Tool execution error: #{e.class} - #{e.message}")
      end
    end
  end

  # Load tools from MCP server
  def load_mcp_tools
    return unless @mcp_server_url.present?

    begin
      require 'net/http'
      require 'uri'

      uri = URI.parse("#{@mcp_server_url}/tools")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.path)
      request["Content-Type"] = "application/json"

      response = http.request(request)

      if response.code.to_i == 200
        mcp_tools = JSON.parse(response.body)
        # Convert MCP tools to OpenAI function format
        @tools = convert_mcp_tools_to_openai_format(mcp_tools)
        Rails.logger.info("Loaded #{@tools.length} tools from MCP server")
      else
        Rails.logger.warn("Failed to load MCP tools: #{response.code}")
      end
    rescue => e
      Rails.logger.warn("MCP tools loading error: #{e.message}")
    end
  end

  # Convert MCP tool format to OpenAI function calling format
  def convert_mcp_tools_to_openai_format(mcp_tools)
    return [] unless mcp_tools.is_a?(Array)

    mcp_tools.map do |tool|
      {
        type: "function",
        function: {
          name: tool["name"],
          description: tool["description"],
          parameters: tool["inputSchema"] || tool["parameters"] || {
            type: "object",
            properties: {},
            required: []
          }
        }
      }
    end
  end

  # Build default tool handler for MCP server
  def build_mcp_tool_handler
    ->(tool_name, arguments) do
      require 'net/http'
      require 'uri'

      uri = URI.parse("#{@mcp_server_url}/tools/execute")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = {
        name: tool_name,
        arguments: arguments
      }.to_json

      response = http.request(request)

      if response.code.to_i == 200
        result = JSON.parse(response.body)
        result["result"] || result
      else
        raise ToolExecutionError, "MCP tool execution failed: #{response.code} - #{response.body}"
      end
    end
  end

  def api_key
    ENV.fetch('LLM_API_KEY') do
      raise LlmError, "LLM_API_KEY not configured"
    end
  end

  def normalize_images(images)
    return [] if images.blank?
    list = images.is_a?(Array) ? images.compact : [images].compact
    list.map(&:to_s).reject(&:blank?)
  end

  # Mock HTTP response for test environment
  def mock_http_response(stream: false, &block)
    if stream
      mock_stream_response(&block)
    else
      mock_blocking_response
    end
  end

  def mock_blocking_response
    # Return OpenAI-compatible response format
    mock_content = generate_mock_content

    {
      "id" => "mock-#{SecureRandom.hex(8)}",
      "object" => "chat.completion",
      "created" => Time.now.to_i,
      "model" => @model,
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => mock_content
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 20,
        "total_tokens" => 30
      }
    }
  end

  def mock_stream_response(&block)
    # Simulate streaming chunks
    chunks = generate_mock_content.chars.each_slice(5).map(&:join)

    chunks.each do |chunk|
      block.call({ content: chunk })
    end

    nil
  end

  def generate_mock_content
    # Generate contextual mock content based on prompt
    return "Fortune reading: Great success awaits you!" if @prompt.to_s.downcase.include?("fortune")
    return "Weather forecast: Sunny with a chance of clouds" if @prompt.to_s.downcase.include?("weather")

    # Default mock response
    "This is a mocked LLM response for testing purposes. Prompt: #{@prompt&.truncate(50)}"
  end
end
