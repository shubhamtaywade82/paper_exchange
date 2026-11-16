# frozen_string_literal: true

# MCP tools are strictly read-only views over the broker simulation engine.
# They must never execute orders, mutate positions, or bypass ledger invariants.
class ApplicationMCPTool < ActionMCP::Tool
  abstract!

  SECRET_KEY_PATTERN = /token|secret|password|passwd|api_key|apikey|webhook|credential/i

  private

  # Recursively masks secret-looking keys before any config/data leaves the process.
  def redact(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, val), out|
        out[key.to_s] = SECRET_KEY_PATTERN.match?(key.to_s) ? "REDACTED" : redact(val)
      end
    when Array then value.map { |v| redact(v) }
    else value
    end
  end

  # Text JSON for MCP clients and small local models.
  def render_json(payload)
    render text: redact(payload).to_json
  end
end
