---
name: session-lifecycle-contract
description: Specify authenticated session creation, renewal, expiry, logout, and invalidation as explicit state transitions.
family: rails
---

# Session Lifecycle Contract

## Problem

Session behavior becomes unsafe when creation, renewal, logout, and expiry are implicit or implemented differently across endpoints.

## Use when

Changing browser sessions, database-backed sessions, session cookies, logout, expiry, device sessions, or current-user loading.

## Do not use when

The application has no session-based authentication boundary.

## Repository inspection

Inspect session model/store, cookies, controller concern, login/logout actions, expiry configuration, revocation fields, and tests.

## Implementation procedure

1. Model anonymous and authenticated states.
2. Define session creation.
3. Define post-login renewal/rotation.
4. Define authenticated request lookup.
5. Define inactivity/absolute expiry if required.
6. Define logout invalidation.
7. Define credential-change invalidation.
8. Define revoke-current and revoke-all semantics.
9. Define multi-device behavior.
10. Test each transition.

## Example

```ruby
# One concern owns creation, lookup, expiry, and termination for every endpoint.
module Authentication
  extend ActiveSupport::Concern
  IDLE_TIMEOUT = 2.hours

  included { before_action :require_authentication }

  private

  def require_authentication
    resume_session || redirect_to(new_session_path)
  end

  def resume_session
    record = Session.find_by(id: cookies.signed[:session_id])
    return terminate_session(record) && nil if record && record.last_active_at < IDLE_TIMEOUT.ago

    record&.touch(:last_active_at)
    Current.session = record
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip, last_active_at: Time.current).tap do |record|
      cookies.signed.permanent[:session_id] = { value: record.id, httponly: true, same_site: :lax }
    end
  end

  def terminate_session(record = Current.session)
    record&.destroy
    cookies.delete(:session_id)
  end
end
```

## Failure modes

- logout only clears UI state
- expired session still resolves current user
- login reuses pre-auth session
- revoke-all misses alternate session store
- device sessions cannot be distinguished safely

## Testing

Use request/system tests for login, protected request, logout, expiry, and revoked-session rejection.

## Review checklist

- [ ] state transitions explicit
- [ ] renewal/rotation explicit
- [ ] expiry explicit
- [ ] logout invalidates authority
- [ ] revoke scope explicit

## Related skills

- rails-authentication
- rails-action-controller
- rails-security
- rails-test-engineering

