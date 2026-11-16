---
name: initializer-dependency-contract
description: Initializer Dependency Contract
family: rails
---
# Initializer Dependency Contract

## Problem
Initializer order becomes fragile when dependencies rely on incidental filename order.

## Use when
An initializer depends on another registration.

## Do not use when
Independent configuration.

## Repository inspection
Inspect initializer order, hooks, framework phases, and consumers.

## Implementation procedure
Move shared setup to the correct lifecycle phase and make dependencies explicit.

## Example

```ruby
# config/initializers/payment_gateway.rb depends on credentials and the logger,
# not on "01_" filename ordering.
Rails.application.config.after_initialize do
  PaymentGateway.configure do |config|
    config.api_key = Rails.application.credentials.dig(:payment_gateway, :api_key) ||
                     raise("payment_gateway.api_key credential missing")
    config.logger = Rails.logger
  end
end

# Inside an engine or railtie, declare the dependency explicitly:
module Payments
  class Railtie < ::Rails::Railtie
    initializer "payments.gateway", after: :load_config_initializers do
      PaymentGateway.instrumenter = ActiveSupport::Notifications
    end
  end
end
```

## Failure modes
Boot races, nil constants, duplicate setup.

## Testing
Run boot/initializer tests.

## Review checklist
[ ] dependency explicit [ ] phase correct [ ] no incidental order

## Related skills
rails-initialization-configuration-engineering, zeitwerk
