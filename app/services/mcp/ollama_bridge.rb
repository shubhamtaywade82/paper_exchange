# frozen_string_literal: true

require "net/http"

module MCP
  # Answers questions with a local Ollama model calling this app's ActionMCP tools
  # over Streamable HTTP (bin/mcp). Talks to the MCP server on port 62770, never directly
  # to internal models, so it sees exactly what external AI clients see.
  class OllamaBridge
    class Error < StandardError; end

    DEFAULT_URL = "http://127.0.0.1:62770/"
    DEFAULT_MODEL = "openbmb/minicpm5-2b"
    OLLAMA_HOST = ENV.fetch("OLLAMA_HOST", "http://127.0.0.1:11434")
    PROTOCOL_VERSION = "2025-11-25"
    MAX_TOOL_ROUNDS = 3
    SYSTEM_PROMPT = <<~PROMPT
      You analyse a trading simulation and paper exchange system using the provided tools.
      Always call a tool before answering. Quote numbers exactly as returned.
      A status of unavailable or stale means the value is not live; say so.
      You cannot place or cancel trades. Answer in a few short plain sentences; no tables or headings.
    PROMPT

    def initialize(token: nil, url: DEFAULT_URL, model: DEFAULT_MODEL)
      @uri = URI(url)
      @token = token
      @model = model
      @request_id = 0
      @tools_used = []
    end

    attr_reader :tools_used, :model

    def list_tools
      open_session!
      rpc("tools/list")["tools"]
    end

    def call_tool(name, arguments = {})
      open_session!
      result = rpc("tools/call", name: name, arguments: arguments)
      text = Array(result["content"]).filter_map { |c| c["text"] }.join("\n")
      raise Error, "MCP tool #{name} failed: #{text}" if result["isError"]

      text
    end

    def ask(question)
      open_session!
      @tools_used = []
      messages = [{ role: "system", content: SYSTEM_PROMPT }, { role: "user", content: question }]
      tools = list_tools.map { |tool| ollama_tool(tool) }

      MAX_TOOL_ROUNDS.times do
        reply = chat(messages, tools)
        return reply[:content].to_s if reply[:tool_calls].blank?

        calls = reply[:tool_calls].map { |call| with_parsed_arguments(call) }
        messages << { role: "assistant", content: reply[:content].to_s, tool_calls: calls }
        calls.each { |call| messages << tool_message(call) }
      end
      chat(messages, nil)[:content].to_s
    end

    private

    def chat(messages, tools)
      uri = URI("#{OLLAMA_HOST}/api/chat")
      payload = { model: @model, messages: messages, stream: false, options: { temperature: 0.1 } }
      payload[:tools] = tools if tools.present?

      res = Net::HTTP.post(uri, payload.to_json, { "Content-Type" => "application/json" })
      raise Error, "Ollama HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      msg = data["message"] || {}
      { content: msg["content"], tool_calls: msg["tool_calls"] || [] }
    end

    def with_parsed_arguments(call)
      args = JSON.parse(call.dig("function", "arguments").presence || "{}") rescue {}
      call.deep_merge("function" => { "arguments" => args.is_a?(Hash) ? args : {} })
    end

    def tool_message(call)
      name = call.dig("function", "name")
      @tools_used << name
      content = begin
        call_tool(name, call.dig("function", "arguments"))
      rescue Error => e
        e.message
      end
      { role: "tool", name: name, content: content }
    end

    def ollama_tool(tool)
      { type: "function",
        function: { name: tool["name"], description: tool["description"], parameters: tool["inputSchema"] } }
    end

    def open_session!
      return if @session_id

      response = post(method: "initialize", params: {
                        protocolVersion: PROTOCOL_VERSION, capabilities: {},
                        clientInfo: { name: "paper-exchange-ollama-bridge", version: "1.0" }
                      })
      @session_id = response["Mcp-Session-Id"] or raise Error, "MCP server returned no session id"
      post(method: "notifications/initialized", params: {}, notification: true)
    end

    def rpc(method, params = {})
      body = JSON.parse(post(method: method, params: params).body)
      raise Error, "MCP #{method} failed: #{body['error']['message']}" if body["error"]

      body["result"]
    end

    def post(method:, params:, notification: false)
      payload = { jsonrpc: "2.0", method: method, params: params }
      payload[:id] = (@request_id += 1) unless notification
      response = Net::HTTP.post(@uri, payload.to_json, headers)
      raise Error, "MCP #{method} HTTP #{response.code}: #{response.body.to_s[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

      response
    end

    def headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream",
        "Authorization" => ("Bearer #{@token}" if @token.present?),
        "MCP-Protocol-Version" => PROTOCOL_VERSION,
        "Mcp-Session-Id" => @session_id
      }.compact
    end
  end
end
