---
name: adapter
description: Use when an external or legacy interface does not match the application's internal contract and should be isolated behind a stable boundary.
family: ruby-design
---

# Adapter

## Problem

A third-party, legacy, or unstable API has an interface that does not fit the application's internal contract.

## Use when

- integrating an external service
- replacing a legacy implementation
- normalizing incompatible APIs
- protecting the domain from vendor-specific details

## Do not use when

- the external API already matches the required contract
- the adapter only forwards every method without adding boundary value

## Repository inspection

Inspect the existing integration boundary, client library, error mapping, configuration, logging, and tests.

## Structure

~~~ruby
class PaymentGatewayAdapter
  def initialize(client)
    @client = client
  end

  def charge(amount)
    response = @client.create_charge(cents: amount.to_i * 100)
    PaymentResult.new(id: response.id)
  rescue ExternalClient::Declined => e
    raise PaymentDeclined, e.message
  end
end
~~~

Do not expose vendor response objects beyond the integration boundary unless the repository explicitly chooses to.

## Implementation procedure

1. Define the application's internal contract.
2. Map external inputs to that contract.
3. Map external failures to domain/application errors.
4. Keep credentials/configuration at the boundary.
5. Add focused contract tests.
6. Keep vendor-specific behavior out of domain code.

## Failure modes

- leaking vendor objects into domain code
- swallowing external failures
- unstable error mapping
- logging secrets
- adapter becoming a second application service

## Testing

Use a fake/stub external client for unit tests and integration/contract tests for important vendor behavior.

## Review checklist

- [ ] internal contract is stable
- [ ] vendor details isolated
- [ ] failures mapped intentionally
- [ ] secrets protected
- [ ] boundary tested

## Related skills

- ruby-gems-io-services
- ruby-oop
- ruby-debugging
- ruby-tdd-refactoring
