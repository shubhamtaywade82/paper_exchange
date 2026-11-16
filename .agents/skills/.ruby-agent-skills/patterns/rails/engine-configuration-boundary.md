---
name: engine-configuration-boundary
description: Engine Configuration Boundary
family: rails
---
# Engine Configuration Boundary

## Problem
Engine behavior becomes fragile when it reads arbitrary host globals instead of an explicit configuration API.

## Use when
Adding or changing engine settings or host-provided policy.

## Do not use when
The value is purely internal implementation state.

## Repository inspection
Inspect engine config APIs, defaults, host overrides, environment variables, credentials, and consumers.

## Implementation procedure
Define namespaced configuration with explicit defaults, override timing, and validation.

## Example

```ruby
module Payments
  class Configuration
    attr_accessor :currency, :webhook_secret, :on_payment_succeeded

    def initialize
      @currency = "USD"
      @on_payment_succeeded = ->(_payment) {}
    end

    def validate!
      raise ArgumentError, "Payments.webhook_secret is required" if webhook_secret.to_s.empty?
    end
  end

  def self.config = @config ||= Configuration.new
  def self.configure = yield(config).then { config.validate! }
end

# host: config/initializers/payments.rb
#   Payments.configure do |config|
#     config.webhook_secret = Rails.application.credentials.dig(:payments, :webhook_secret)
#     config.on_payment_succeeded = ->(payment) { Orders::MarkPaid.call(payment.order_id) }
#   end
```

## Failure modes
Stringly-typed drift, hidden host coupling, boot-order dependence.

## Testing
Test defaults, host overrides, invalid configuration, and boot timing.

## Review checklist
[ ] public config [ ] defaults [ ] override semantics [ ] validation

## Related skills
rails-engines-railties-engineering, rails-initialization-configuration-engineering