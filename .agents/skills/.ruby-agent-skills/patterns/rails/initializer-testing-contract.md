---
name: initializer-testing-contract
description: Initializer Testing Contract
family: rails
---
# Initializer Testing Contract

## Problem
Static inspection cannot prove boot-time registration or lifecycle behavior.

## Use when
A change affects initialization/configuration.

## Do not use when
Pure application code with no initialization effect.

## Repository inspection
Inspect existing boot/config test conventions.

## Implementation procedure
Test the lifecycle boundary and add clean boot coverage for deployment-critical behavior.

## Example

```ruby
require "test_helper"

class InitializerContractTest < ActiveSupport::TestCase
  test "payment gateway is configured at boot" do
    assert_not_nil PaymentGateway.config.api_key
    assert_same Rails.logger, PaymentGateway.config.logger
  end

  test "instrumentation subscriber is registered exactly once" do
    listeners = ActiveSupport::Notifications.notifier.listeners_for("charge.payments")
    assert_equal 1, listeners.count
  end
end

# CI also boots production-like: RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails zeitwerk:check
```

## Failure modes
Hidden environment state and tests that never execute the initializer.

## Testing
Run isolated tests and clean-process boot verification where practical.

## Review checklist
[ ] lifecycle executed [ ] env assumptions explicit [ ] boot regression

## Related skills
rails-initialization-configuration-engineering, rails-test-engineering
