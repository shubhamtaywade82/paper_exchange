---
name: runtime-config-contract
description: Validate required production configuration and secrets without exposing secret values.
family: rails
---

# Runtime Config Contract

## Problem
Production processes fail when required environment variables, credentials, or runtime settings are missing or accidentally baked into artifacts.

## Use when
Changing environment variables, Rails credentials, container build/runtime configuration, or production boot requirements.

## Implementation procedure
1. Enumerate required configuration keys.
2. Classify build-time versus runtime configuration.
3. Validate presence without printing values.
4. Validate credential/master-key availability where required.
5. Verify non-secret defaults and allowed ranges.
6. Test boot with missing required configuration.

## Example

```ruby
# config/initializers/00_required_config.rb — fail fast at boot, never print values.
REQUIRED_ENV = %w[DATABASE_URL REDIS_URL APP_HOST].freeze
REQUIRED_CREDENTIALS = [%i[payment_gateway api_key], %i[smtp password]].freeze

if Rails.env.production?
  missing = REQUIRED_ENV.reject { ENV[_1].present? }
  missing += REQUIRED_CREDENTIALS.reject { Rails.application.credentials.dig(*_1).present? }.map { _1.join(".") }
  raise "Missing required configuration: #{missing.join(', ')}" if missing.any?
end
# Values come from the runtime environment (Kamal secrets / k8s Secret), never the image.
```

## Failure modes
- secret values printed in CI/logs
- runtime secrets baked into container layers
- optional and required configuration conflated
- production boot succeeds with unsafe fallback defaults

## Testing
Test presence/absence and boot behavior without asserting secret values.

## Review checklist
- required keys documented
- build/runtime boundary explicit
- secrets protected
- missing configuration fails clearly


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when the change does not affect production runtime configuration, secrets, or boot-time required settings.
