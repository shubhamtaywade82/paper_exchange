# Run using bin/ci
#
# Local mirror of .github/workflows/ci.yml. Each step runs the same check as the
# matching GitHub Actions step, so a clean local run should pass the CI jobs.

# The test steps below purge and reload the database that RAILS_ENV=test resolves
# to. DATABASE_URL overrides that database, and the dev container sets it to the
# development database, so refuse to run unless the URL names a *_test database.
if (url = ENV["DATABASE_URL"]) && !URI(url).path.to_s.end_with?("_test")
  abort "bin/ci: DATABASE_URL points at #{URI(url).path.inspect}, not a *_test database. Refusing to purge it."
end

CI.run do
  step "Lint: RuboCop", "bin/rubocop"

  step "Security: committed secrets", "bash script/check_committed_secrets.sh"
  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: prepare test database", "env RAILS_ENV=test bin/rails db:test:prepare"
  step "Tests: pending migrations", "env RAILS_ENV=test bin/rails db:abort_if_pending_migrations"
  step "Tests: RSpec", "env RAILS_ENV=test bin/rails spec"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
