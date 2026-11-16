# Agent guide: paper_exchange

Rails 8.1 API-only app, Ruby 4.0, RSpec. Everything runs in Docker (`api`, `db`, `redis`, `jobs`).

## Running tests (read before running anything)

The `api` container sets `RAILS_ENV=development` and `DATABASE_URL` pointing at the **dev** database.
`spec/rails_helper.rb` only defaults to test (`||=`), so a bare `rspec` in the container runs in
development mode: 403 on every request, and it touches the dev database. Always pass both overrides:

```sh
docker compose exec -T \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://paper_user:paper_password@db:5432/paper_exchange_test \
  api bundle exec rspec [path]
```

Expected: 775 examples, 0 failures. Lint: `docker compose exec -T api bin/rubocop`. Security: `bin/brakeman`.

## MCP servers (`.mcp.json`, `.cursor/mcp.json`, `.vscode/mcp.json`, `opencode.json`)

- `rails-harness`: schema, routes, models, DB queries, logs. Needs the `api` container up.
  Do **not** use its `run_tests`: it assumes `bin/rails test`, runs 0 tests, and reports success.
- `railsforge`: read-only code intelligence (schema, routes, duplicate methods). Its linter and test
  tools stay disabled unless `RAILSFORGE_MCP_EXECUTION=project-code` is set. The server path is a
  local VS Code extension install; update it if the version changes.
- `debug`: needs `RUBY_DEBUG_OPEN=true` in `.env` and an `api` restart. `connect` pauses the server;
  always `continue_execution` or `disconnect` afterwards.

## Conventions

- Money paths go through `Ledger::MarginLedger`; ledger entries are append-only.
- Live-account writes are fenced by the account lease: present `X-Lease-Holder` and `X-Lease-Fence` (`POST /api/account/lease`). Operator force-release is host-side only: `ACCOUNT_ID=... OPERATOR=... REASON=... bin/rails account_leases:force_release`.
- Validate external input at controller boundaries (see `MarkPricesController`).
- Do not commit without being asked.

## ActionMCP Server (this app as an MCP server)

- `bin/mcp`: Puma on 127.0.0.1:62770, pidfile `tmp/pids/mcp.pid`; never mount `ActionMCP::Engine` in routes.
- Tools in `app/mcp/tools/` are **read-only** views over the broker simulation and market engine. `spec/mcp/application_mcp_tool_spec.rb` pins the tool list and fails if MCP code references order placement or mutations.
- Auth: clients on this machine (loopback, no forwarding headers) need no token; remote clients need `Authorization: Bearer $MCP_API_TOKEN` (unset = open in dev, rejected in production).
- Local LLM client: `bin/rails "mcp:ask[question]"` — `MCP::OllamaBridge` drives Ollama (`openbmb/minicpm5-2b` by default, override `MCP_OLLAMA_MODEL`) through the MCP server over HTTP.
- REST API: `GET /api/v1/mcp/tools`, `POST /api/v1/mcp/tools/:tool_id/calls`, `POST /api/v1/mcp/questions` (`Api::MCP::*` controllers).

## Ruby/Rails MCP Tooling Policy (verified 2026-11-16)

Escalation order for connected MCP servers — static/structured first, arbitrary execution last:

1. **`rails-context`** (rails-mcp-server 2.0, read-only; 3 bootstrap tools: `switch_project`, `search_tools`, `execute_tool`):
   - Load house rules first: `execute_tool("load_guide", { library: "custom", guide: "paper-exchange-architecture" })`.
   - DB + route ground truth via `execute_tool("get_schema", ...)` / `execute_tool("get_routes", ...)` — never infer schema from migrations.
   - `analyze_models` only sees `app/models`; it does NOT see anything under `app/services/`, `app/jobs/`, `lib/`. Use `rg`/read for those.
   - RailsForge MCP overlaps on `list_routes`/`get_project_guidelines` — prefer `rails-context` for database truth.
2. **Verification loop stays in-shell** per test instructions above (`docker compose exec -T -e RAILS_ENV=test -e DATABASE_URL=postgres://paper_user:paper_password@db:5432/paper_exchange_test api bundle exec rspec`). `rails-harness` (ask-rails-harness-mcp: `run_tests`, `read_log`, `query_database`, `run_command`, `schema_graph`, `route_inspector`) runs inside the `api` container. Do NOT use its `run_tests`: it assumes `bin/rails test`, runs 0 tests, and reports success.
3. **`ruby-console`** (ruby-console-mcp) — persistent PTY REPL, arbitrary Ruby eval via `docker compose exec api bin/rails c --sandbox`. Enabled in all clients, yet last resort in this escalation order; never used against live-trading state; never prints tokens/ENV.
4. **`ruby-debug` / `debug`** (debug-mcp) — attaches to rdbg on port 12345 when `RUBY_DEBUG_OPEN=true`. Use only for live debugging; never in production.

Trading safety overrides all tooling: money paths go through `Ledger::MarginLedger` (append-only); live-account writes are fenced by `X-Lease-Holder` and `X-Lease-Fence`; index cash trading is permanently prohibited; never print secrets or `.env` contents.
