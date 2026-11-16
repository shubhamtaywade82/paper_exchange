---
name: login-abuse-controls
description: Design bounded defenses against credential stuffing, brute force, account enumeration, reset abuse, and authentication endpoint overload.
family: rails
---

# Login Abuse Controls

## Problem

Authentication endpoints are public and computationally expensive, making them targets for credential attacks and denial of service.

## Use when

Adding login throttling, lockout, CAPTCHA/challenges, anomaly detection, reset throttling, or abuse response.

## Do not use when

Only implementing a local form validation rule unrelated to attack volume.

## Repository inspection

Inspect authentication endpoints, identity normalization, rate-limit store, failure telemetry, reverse proxy/WAF controls, reset endpoints, and existing security controls.

## Implementation procedure

1. Identify threats and attacker-controlled dimensions.
2. Define failure semantics.
3. Prevent account enumeration.
4. Add bounded throttling by appropriate dimensions.
5. Add progressive challenge/lock behavior if required.
6. Define reset/recovery throttles.
7. Ensure controls do not become permanent denial-of-service primitives.
8. Instrument bounded abuse signals.
9. Test threshold and recovery behavior.

## Example

```ruby
class SessionsController < ApplicationController
  # Rails 8 built-in limiter, backed by the shared cache store (not per-process memory).
  rate_limit to: 10, within: 3.minutes, only: :create,
             by: -> { request.remote_ip },
             with: -> { redirect_to new_session_path, alert: "Try again later." }

  def create
    if (user = User.authenticate_by(email_address: params[:email_address], password: params[:password]))
      start_new_session_for(user)
      redirect_to after_authentication_url
    else
      # Same message for unknown email and wrong password: no account enumeration.
      redirect_to new_session_path, alert: "Invalid email address or password."
    end
  end
end
# authenticate_by runs the password digest even when no user matches (constant-ish timing).
```

## Failure modes

- one global IP limit
- permanent account lockout
- different responses for existing/non-existing users
- reset endpoint unrestricted
- high-cardinality attacker input in metrics

## Testing

Test repeated failures, threshold behavior, safe recovery, enumeration resistance, and successful login after throttle expiration.

## Review checklist

- [ ] threat model explicit
- [ ] throttles bounded
- [ ] enumeration minimized
- [ ] recovery path safe
- [ ] telemetry bounded

## Related skills

- rails-authentication
- rails-security
- rails-reliability-engineering
- rails-observability

