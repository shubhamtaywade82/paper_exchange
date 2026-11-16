---
name: credentials-redaction-contract
description: Secret Redaction and Filtering Contract
family: rails
---
# Secret Redaction and Filtering Contract

## Problem
Secrets can leak through logs, SQL, job payloads, traces, object inspection, or support tooling even when stored securely.

## Use when
Adding sensitive credentials or encrypted attributes.

## Do not use when
The value is demonstrably non-sensitive.

## Repository inspection
Inspect filter_parameters, SQL logging, structured logging, tracing, exception reporting, job arguments, and model inspect output.

## Implementation procedure
Configure redaction at each applicable observability boundary and test that representative values are filtered.

## Example

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += %i[passw secret token _key crypt salt certificate otp ssn cvv cvc]

class PaymentMethod < ApplicationRecord
  encrypts :card_token
  # inspect, logs, and error reports show "[FILTERED]" for these attributes.
  self.filter_attributes += %i[card_token billing_email]
end

# Job arguments are logged by Active Job; pass ids, never secrets.
ChargeJob.perform_later(payment_method.id) # not the token
```

## Failure modes
Secret leakage through a secondary channel such as logs or traces.

## Testing
Assert logs/exceptions/job inspection do not contain representative secret values.

## Review checklist
[ ] parameters filtered [ ] attributes filtered [ ] tracing reviewed [ ] jobs reviewed

## Related skills
rails-encryption-credentials-engineering, rails-observability, rails-security-engineering