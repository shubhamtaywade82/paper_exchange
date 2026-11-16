---
name: password-recovery-contract
description: Implement password reset as a one-time, expiring authentication protocol with enumeration-safe responses and explicit post-reset revocation.
family: rails
---

# Password Recovery Contract

## Problem

Password reset is an authentication protocol. Treating it as a simple update creates token replay, enumeration, stale-session, or delivery failures.

## Use when

Adding or changing forgot-password, reset-token, password-change, recovery mail, or recovery notifications.

## Do not use when

Changing unrelated user profile fields.

## Repository inspection

Inspect reset token model/storage, expiration, mailer/job, routes, controller, password update, session revocation, and rate limits.

## Implementation procedure

1. Define reset request behavior.
2. Make account-existence response safe.
3. Generate/store a short-lived reset credential.
4. Deliver it through the trusted channel.
5. Enforce expiry and one-time consumption.
6. Change the password through the canonical credential API.
7. Revoke affected sessions/tokens.
8. Audit the event.
9. Rate-limit abuse.
10. Test valid, expired, replayed, and invalid tokens.

## Example

```ruby
class User < ApplicationRecord
  has_secure_password
  # Token embeds the password salt: it stops working once the password changes (single use).
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt.last(10)
  end
end

class PasswordsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create

  def create
    if (user = User.find_by(email_address: params[:email_address]))
      PasswordsMailer.reset(user, user.generate_token_for(:password_reset)).deliver_later
    end
    redirect_to new_session_path, notice: "If the address exists, we've sent instructions." # no enumeration
  end

  def update
    user = User.find_by_token_for(:password_reset, params[:token]) or
      return redirect_to(new_password_path, alert: "Link is invalid or expired.")
    if user.update(params.permit(:password, :password_confirmation))
      user.sessions.destroy_all # revoke every existing session
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end
end
```

## Failure modes

- token never expires
- token reusable
- raw token persisted unnecessarily
- reset request reveals account existence
- compromised sessions survive reset without an explicit decision
- token appears in logs

## Testing

Test enumeration-safe request, valid reset, expired token, replay, invalid token, and post-reset session state.

## Review checklist

- [ ] one-time token semantics
- [ ] expiration
- [ ] safe response
- [ ] revocation
- [ ] abuse controls
- [ ] secret-safe logging

## Related skills

- rails-authentication
- rails-action-mailer
- rails-active-job
- rails-security

