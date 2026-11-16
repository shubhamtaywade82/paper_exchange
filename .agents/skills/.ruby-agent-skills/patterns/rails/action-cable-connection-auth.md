---
name: action-cable-connection-auth
description: Define authentication and connection identity for Rails Action Cable without confusing identity with channel authorization.
family: rails
---

# Action Cable Connection Authentication

## Problem

A WebSocket connection is long-lived and can carry many subscriptions, so authentication must establish identity without becoming a blanket authorization grant.

## Use when

- changing ApplicationCable::Connection;
- changing cookie/session/token authentication for WebSockets.

## Do not use when

- the task does not involve WebSocket connection authentication.

## Repository inspection

Inspect authentication/session strategy, connection identifiers, allowed origins, revocation behavior, and existing channel authorization.

## Implementation procedure

1. Identify the authentication credential.
2. Resolve the caller.
3. Set only safe connection identifiers.
4. Reject unauthenticated connections.
5. Keep resource authorization in channels.
6. Test accepted/rejected connection paths.

## Example

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    # Reuses the web session's signed cookie; revoked sessions cannot connect.
    def find_verified_user
      session = Session.active.find_by(id: cookies.signed[:session_id])
      session&.user || reject_unauthorized_connection
    end
  end
end
```

## Failure modes

- unauthenticated sockets accepted;
- authentication treated as authorization;
- sensitive connection identifiers;
- credentials logged;
- revocation semantics ignored.

## Testing

Test authorized, missing, expired, and invalid credentials.

## Review checklist

- [ ] identity source
- [ ] rejection behavior
- [ ] safe identifier
- [ ] channel auth remains separate
- [ ] tests

## Related skills

rails-action-cable, rails-security, rails-authentication, rails-security-engineering
