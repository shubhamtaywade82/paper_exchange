---
name: reload-safe-initializer
description: Reload-Safe Initializer
family: rails
---
# Reload-Safe Initializer

## Problem
Reloads can duplicate registrations or retain stale class references.

## Use when
Initializers touch reloadable classes, subscribers, callbacks, or registries.

## Do not use when
Boot-only immutable configuration.

## Repository inspection
Inspect autoload paths, to_prepare hooks, registrations, and development reload.

## Implementation procedure
Make reload-sensitive setup idempotent and avoid retaining reloadable objects.

## Example

```ruby
# config/initializers/webhook_handlers.rb
Rails.application.config.to_prepare do
  # Runs again after every reload: rebuild the registry from current constants
  # instead of appending (which would duplicate handlers and keep stale classes).
  Webhooks::Registry.replace(
    "invoice.paid" => Webhooks::InvoicePaidHandler,
    "customer.deleted" => Webhooks::CustomerDeletedHandler
  )
end

module Webhooks
  module Registry
    @handlers = {}.freeze
    def self.replace(map) = @handlers = map.freeze
    def self.fetch(type) = @handlers.fetch(type)
  end
end
# Registry lives in lib/ (not reloaded); the handler classes live in app/ (reloaded).
```

## Failure modes
Duplicate subscriptions, stale constants, memory growth.

## Testing
Exercise repeated preparation/reload behavior.

## Review checklist
[ ] reload boundary [ ] idempotent [ ] stale refs avoided

## Related skills
rails-initialization-configuration-engineering, zeitwerk
