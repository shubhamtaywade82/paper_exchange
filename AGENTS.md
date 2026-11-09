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

Expected: 692 examples, 0 failures. Lint: `docker compose exec -T api bin/rubocop`. Security: `bin/brakeman`.

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
- Validate external input at controller boundaries (see `MarkPricesController`).
- Do not commit without being asked.
