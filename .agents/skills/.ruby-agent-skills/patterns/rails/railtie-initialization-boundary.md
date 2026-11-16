---
name: railtie-initialization-boundary
description: Railtie Initialization Boundary
family: rails
---
# Railtie Initialization Boundary

## Problem
Railtie hooks can create hidden boot dependencies when lifecycle ownership is unclear.

## Use when
A plugin needs Rails configuration or initialization hooks without a full Engine.

## Do not use when
The extension needs routes/controllers/models/views as a packaged application boundary.

## Repository inspection
Inspect Railtie hooks, host initialization order, reload behavior, and required frameworks.

## Implementation procedure
Keep Railtie hooks narrow, idempotent when needed, and limited to extension setup.

## Example

```ruby
module AuditTrail
  class Railtie < ::Rails::Railtie
    config.audit_trail = ActiveSupport::OrderedOptions.new
    config.audit_trail.enabled = true

    # Runs after the host's config/initializers, so host overrides are visible.
    initializer "audit_trail.configure", after: :load_config_initializers do |app|
      AuditTrail.enabled = app.config.audit_trail.enabled
    end

    # Touch Active Record only when it loads; do not force it during boot.
    ActiveSupport.on_load(:active_record) do
      include AuditTrail::Model
    end
  end
end
```

## Failure modes
Duplicate initialization, partial boot, hidden ordering, business workflow execution during boot.

## Testing
Test registration, initialization, and repeated preparation where applicable.

## Review checklist
[ ] scope justified [ ] lifecycle explicit [ ] idempotence [ ] no business workflow

## Related skills
rails-engines-railties-engineering, rails-initialization-configuration-engineering