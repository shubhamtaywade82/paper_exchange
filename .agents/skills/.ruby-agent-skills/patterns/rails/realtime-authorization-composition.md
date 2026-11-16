---
name: realtime-authorization-composition
description: Realtime Authorization Composition Contract
family: security
---
# Realtime Authorization Composition Contract

## Problem
Realtime connections can outlive authorization changes and expose streams or mutations.

## Use when
Action Cable or another realtime channel is protected.

## Do not use when
A channel carries only public information and cannot cause sensitive side effects.

## Repository inspection
Inspect connection identity, subscription parameters, streams, channel actions, and membership revocation.

## Implementation procedure
Authorize connection, resource/subscription, and sensitive action at appropriate boundaries; stop revoked streams.

## Example

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # Authentication: who is connected.
      self.current_user = Session.find_by(id: cookies.signed[:session_id])&.user || reject_unauthorized_connection
    end
  end
end

class ProjectChannel < ApplicationCable::Channel
  def subscribed
    # Authorization: may this user see this project's stream?
    project = Project.find_by(id: params[:id])
    return reject unless project && ProjectPolicy.new(current_user, project).show?

    stream_for project
  end
end

# On membership removal, cut existing subscriptions:
#   ActionCable.server.remote_connections.where(current_user: user).disconnect
```

## Failure modes
Stream leakage, stale membership, mutation without resource authorization.

## Testing
Test unauthorized subscriptions, revocation, reconnect, and sensitive actions.

## Review checklist
[ ] connection auth [ ] stream auth [ ] mutation auth [ ] revocation

## Related skills
rails-cross-boundary-authorization-security, rails-action-cable, rails-authorization