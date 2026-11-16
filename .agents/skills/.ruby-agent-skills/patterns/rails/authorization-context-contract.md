---
name: authorization-context-contract
description: Authorization Context Contract
family: security
---
# Authorization Context Contract

## Problem
Security decisions drift when actor, tenant, resource state, or execution context is implicit.

## Use when
A protected operation is invoked across multiple layers.

## Do not use when
A simple policy has one explicit caller and no contextual boundary changes.

## Repository inspection
Inspect policy inputs, current_user/current_actor usage, tenant context, service identity, and callers.

## Implementation procedure
Define an explicit authorization context containing only required security facts and pass it deliberately.

## Example

```ruby
# The decision receives everything it depends on, explicitly.
AuthorizationContext = Data.define(:actor, :tenant, :action, :resource, :via) do
  def self.for_request(controller, action, resource)
    new(actor: controller.current_user, tenant: controller.current_tenant, action:, resource:, via: :web)
  end
end

class DocumentPolicy
  def self.allowed?(context)
    return false unless context.resource.tenant_id == context.tenant.id
    return true if context.actor.admin_of?(context.tenant)

    context.action == :read && context.resource.shared_with?(context.actor)
  end
end
```

## Failure modes
Ambient context, missing tenant, stale actor state, and caller-dependent policy behavior.

## Testing
Test equivalent decisions with explicit contexts.

## Review checklist
[ ] actor explicit [ ] tenant/context explicit [ ] no hidden security state

## Related skills
rails-cross-boundary-authorization-security, rails-authorization