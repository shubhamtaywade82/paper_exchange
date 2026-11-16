---
name: boot-failure-contract
description: Boot Failure Contract
family: rails
---
# Boot Failure Contract

## Problem
A partially configured process is more dangerous than an explicit startup failure.

## Use when
Required configuration or initialization can fail at boot.

## Do not use when
Optional runtime behavior that can degrade safely.

## Repository inspection
Inspect required/optional settings, health checks, and error reporting.

## Implementation procedure
Fail fast for required invariants with actionable, secret-free diagnostics.

## Example

```ruby
# config/initializers/required_configuration.rb
# Fail fast with the names that are missing, never their values.
REQUIRED_ENV = %w[DATABASE_URL REDIS_URL RAILS_MASTER_KEY APP_HOST].freeze

if Rails.env.production?
  missing = REQUIRED_ENV.reject { |name| ENV[name].present? }
  raise "Missing required configuration: #{missing.join(", ")}" if missing.any?
end
```

## Failure modes
Swallowed errors, false health, secret leakage, retry loops.

## Testing
Test missing config, invalid values, dependency failures, and successful boot.

## Review checklist
[ ] fail fast [ ] actionable diagnostics [ ] secrets excluded [ ] health aligned

## Related skills
rails-initialization-configuration-engineering, rails-observability, rails-production-runtime
