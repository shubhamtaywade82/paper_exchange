---
name: action-cable-broadcast-contract
description: Design small versioned Action Cable broadcast payloads and define compatibility, ordering, and authorization semantics.
family: rails
---

# Action Cable Broadcast Contract

## Problem

Realtime payloads are wire contracts even when no public API document exists.

## Use when

- changing broadcast payloads;
- adding client consumers;
- rolling out incompatible realtime schema changes.

## Do not use when

- the broadcast is a temporary internal signal with no client contract.

## Repository inspection

Inspect event producers, serializers, client consumers, version/deployment overlap, and sensitive fields.

## Implementation procedure

1. Define event type.
2. Define payload schema/version.
3. Keep payload minimal.
4. Define omission/null semantics.
5. Define compatibility for old clients.
6. Define authorization assumptions.
7. Add producer/consumer contract tests.

## Example

```ruby
# A versioned, minimal payload: clients depend on these keys, not on model
# attributes, and private fields never reach the socket.
class ProjectBroadcast
  VERSION = 1

  def self.updated(project)
    ProjectChannel.broadcast_to(project, {
      v: VERSION,
      type: "project.updated",
      id: project.id,
      name: project.name,
      updated_at: project.updated_at.iso8601
    })
  end
end
```

## Failure modes

- serializing full Active Record objects;
- exposing private fields;
- breaking old clients during rolling deploy;
- ambiguous null/omission semantics.

## Testing

Test expected payload fields, versions, and compatibility cases.

## Review checklist

- [ ] schema
- [ ] minimal payload
- [ ] compatibility
- [ ] sensitive-field review
- [ ] tests

## Related skills

rails-action-cable, rails-api-integration, rails-event-driven-messaging
