@AGENTS.md

## ActionMCP Server (this app as an MCP server)

- `bin/mcp`: Puma on 127.0.0.1:62770, pidfile `tmp/pids/mcp.pid`; never mount `ActionMCP::Engine` in routes
- Tools in `app/mcp/tools/` are **read-only** views over the broker simulation and market engine. `spec/mcp/application_mcp_tool_spec.rb` pins the tool list and fails if MCP code references order placement or mutations
- Auth: clients on this machine (loopback, no forwarding headers) need no token; remote clients need `Authorization: Bearer $MCP_API_TOKEN` (unset = open in dev, rejected in production)
- Local LLM client: `bin/rails "mcp:ask[question]"` — `MCP::OllamaBridge` drives Ollama (`openbmb/minicpm5-2b` by default, override `MCP_OLLAMA_MODEL`) through the MCP server over HTTP
- REST API: `GET /api/v1/mcp/tools`, `POST /api/v1/mcp/tools/:tool_id/calls`, `POST /api/v1/mcp/questions` (`Api::MCP::*` controllers) — all go through the MCP server over loopback

## MCP Tooling

Follow the "Ruby/Rails MCP Tooling Policy" section in `AGENTS.md` — escalation order: `rails-context` (read-only) → in-shell `rspec` verification → `ruby-console` / `ruby-debug` (enabled but last resort, never against live-trading state).
