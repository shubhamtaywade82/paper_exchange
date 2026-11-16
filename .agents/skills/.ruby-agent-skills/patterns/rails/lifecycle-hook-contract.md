---
name: lifecycle-hook-contract
description: Lifecycle Hook Contract
family: rails
---
# Lifecycle Hook Contract

## Problem
Boot, preparation, and runtime hooks have different execution semantics.

## Use when
Using before_initialize, after_initialize, to_prepare, or related hooks.

## Do not use when
Ordinary request/job behavior.

## Repository inspection
Inspect Rails version, reload mode, existing hooks, and reloadable code.

## Implementation procedure
Choose the narrowest correct lifecycle phase and execution frequency.

## Example

```ruby
# Boot, once: configuration that never changes during the process.
Rails.application.config.after_initialize do
  Money.default_currency = Money::Currency.new("INR")
end

# Every code reload (and once in production): anything referencing reloadable constants.
Rails.application.config.to_prepare do
  Order.include(Auditable) unless Order < Auditable
end

# Per request/job execution: state reset around each unit of work.
Rails.application.executor.to_complete do
  RequestStore.clear!
end
```

## Failure modes
Duplicate callbacks, stale classes, missed initialization.

## Testing
Test boot and reload-sensitive behavior.

## Review checklist
[ ] phase justified [ ] frequency understood [ ] reload tested

## Related skills
rails-initialization-configuration-engineering, zeitwerk
