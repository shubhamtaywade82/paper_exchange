---
name: boot-external-dependency-boundary
description: Boot External Dependency Boundary
family: rails
---
# Boot External Dependency Boundary

## Problem
External services accessed during boot make restarts fragile and slow.

## Use when
Boot requires an external dependency by explicit contract.

## Do not use when
The dependency can be resolved lazily.

## Repository inspection
Inspect startup dependencies, timeouts, readiness, restart behavior, and failure policy.

## Implementation procedure
Prefer lazy access; otherwise bound timeouts and define required/optional failure semantics.

## Example

```ruby
# config/initializers/feature_flags.rb
# Do not call the flag service while booting; build the client lazily with
# timeouts, so a slow or failing service cannot block deploys or restarts.
Rails.application.config.to_prepare do
  FeatureFlags.client = -> { FeatureFlags::Client.new(url: ENV.fetch("FLAGS_URL"), timeout: 1) }
end

module FeatureFlags
  mattr_accessor :client

  def self.enabled?(flag)
    Rails.cache.fetch(["flag", flag], expires_in: 30.seconds) { client.call.enabled?(flag) }
  rescue FeatureFlags::Client::Error
    false # documented fallback when the service is unavailable
  end
end
```

## Failure modes
Restart storms, indefinite waits, false readiness.

## Testing
Test success, timeout, unavailable dependency, and health behavior.

## Review checklist
[ ] necessity [ ] timeout [ ] failure policy [ ] readiness

## Related skills
rails-initialization-configuration-engineering, rails-reliability-engineering, rails-production-runtime
