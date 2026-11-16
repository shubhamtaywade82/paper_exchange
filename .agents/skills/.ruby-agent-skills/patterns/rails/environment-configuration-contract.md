---
name: environment-configuration-contract
description: Environment Configuration Contract
family: rails
---
# Environment Configuration Contract

## Problem
Intentional environment differences can become accidental divergence.

## Use when
Changing config/environments or environment-dependent behavior.

## Do not use when
A setting is identical everywhere.

## Repository inspection
Inspect environment files, application defaults, deployment config, and tests.

## Implementation procedure
Document why the difference exists and verify affected environments.

## Example

```ruby
# config/environments/production.rb — every divergence from development is deliberate.
Rails.application.configure do
  config.eager_load = true                   # dev: false (reloading)
  config.consider_all_requests_local = false # dev: true (debug pages)
  config.force_ssl = true                    # dev: false (no TLS locally)
  config.cache_store = :solid_cache_store    # dev: :memory_store
  config.active_job.queue_adapter = :solid_queue
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
end

# test/config/environment_contract_test.rb — pins the intentional differences.
require "test_helper"

class EnvironmentContractTest < ActiveSupport::TestCase
  test "production eager loads and forces SSL" do
    source = Rails.root.join("config/environments/production.rb").read
    assert_match(/config\.eager_load = true/, source)
    assert_match(/config\.force_ssl = true/, source)
  end
end
```

## Failure modes
Production-only failures and leaked development settings.

## Testing
Run environment-appropriate tests/boot checks.

## Review checklist
[ ] difference justified [ ] environments tested [ ] production path

## Related skills
rails-initialization-configuration-engineering, rails-production-runtime
