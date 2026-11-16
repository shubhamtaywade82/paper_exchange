---
name: custom-activejob-serializer-contract
description: Custom Active Job Serializer Contract
family: rails
---
# Custom Active Job Serializer Contract

## Problem
Custom serializers can create reload, security, or compatibility defects when their lifecycle and wire representation are implicit.

## Use when
Adding a custom ActiveJob serializer.

## Do not use when
Built-in supported argument types are sufficient.

## Repository inspection
Inspect serializer location, initialization, autoload or once-load behavior, serialized keys, type discrimination, and compatibility.

## Implementation procedure
Serialize into supported primitive/container values, follow the framework serializer contract, register safely, and keep serializer classes loadable for their lifecycle.

## Example

```ruby
Money = Data.define(:cents, :currency)

# Wire format: {"cents" => Integer, "currency" => String}; changing it is a
# compatibility change for jobs already enqueued.
class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize(money) = super("cents" => money.cents, "currency" => money.currency)
  def deserialize(hash) = Money.new(cents: hash.fetch("cents"), currency: hash.fetch("currency"))

  private

  def klass = Money
end

# config/initializers/active_job.rb
Rails.application.config.active_job.custom_serializers << MoneySerializer
```

## Failure modes
Reload-time constants, ambiguous payload types, incompatible historical jobs, arbitrary object construction.

## Testing
Test registration, encode/decode round trips, historical payloads, and restart behavior.

## Review checklist
[ ] load lifecycle [ ] primitive representation [ ] discriminator [ ] historical payload

## Related skills
rails-serialization-globalid-engineering, rails-active-job, rails-initialization-configuration-engineering