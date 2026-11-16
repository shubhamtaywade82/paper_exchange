---
name: turbo-stream-broadcast-contract
description: Safely broadcast committed Turbo Stream updates to authorized subscribers.
family: rails
---
# Turbo Stream Broadcast Contract

## Problem
Broadcasts leak private data or publish state before it is durable.

## Structure
Broadcast only after committed state, use explicit stream naming, and preserve tenant/resource authorization.

## Example

```ruby
class Message < ApplicationRecord
  belongs_to :room

  # after_*_commit: subscribers never see a message that later rolls back.
  # Stream name is the signed [room] identity; the channel verifies the signature,
  # and access to the page that subscribed was authorized by the controller.
  after_create_commit -> { broadcast_append_later_to room, target: "messages", partial: "messages/message" }
  after_destroy_commit -> { broadcast_remove_to room }
end

# View: <%= turbo_stream_from @room %> — only rendered after authorize @room.
# The partial renders only fields every room member may see.
```

## Failure modes
Pre-commit broadcasts, cross-tenant stream names, duplicate updates, and oversized payloads.

## Testing
Cover authorized subscriptions, target isolation, commit ordering, and replay/reconnect behavior where applicable.

## Do not use when
The interaction does not require multi-client realtime updates.

## Repository inspection
Inspect transaction boundaries, Action Cable streams, authorization, tenant naming, and event/broadcast tests.

## Implementation procedure
Publish after commit, derive stream identity from trusted context, bound payloads, and define reconnect/replay behavior.

## Failure modes
Pre-commit broadcast, cross-tenant leakage, duplicate updates, and durable-state confusion.

## Testing
Test authorization, commit ordering, target isolation, and duplicate/reconnect behavior where required.

## Review checklist
Durable state is authoritative and broadcast scope is explicit.

## Related skills
rails-hotwire, rails-action-cable, rails-event-driven-messaging, rails-reliability-engineering

## Use when

Use this pattern when the described Hotwire interaction is an explicit part of the page contract and its lifecycle needs dedicated guidance.
