---
name: signed-globalid-integrity-contract
description: Signed Global ID Integrity Contract
family: rails
---
# Signed Global ID Integrity Contract

## Problem
Opaque identifiers passed through clients can be tampered with when integrity is not protected.

## Use when
A Global ID is exposed where clients can modify the referenced identity.

## Do not use when
The identifier is internal and integrity is already enforced by another trusted channel.

## Repository inspection
Inspect verifier/key ownership, expiry, purpose, transport, and authorization checks.

## Implementation procedure
Use Signed Global ID with explicit verifier, purpose, and lifetime; authorize the resolved object separately.

## Example

```ruby
# Issue: purpose-bound and expiring.
token = invitation.to_sgid(for: "accept_invitation", expires_in: 7.days).to_s

# Resolve: a tampered, expired, or wrong-purpose token returns nil.
class InvitationAcceptancesController < ApplicationController
  def create
    invitation = GlobalID::Locator.locate_signed(params.require(:token), for: "accept_invitation", only: Invitation)
    return head :not_found unless invitation&.pending?
    # Integrity proves we issued it; it does not prove this user may accept it.
    return head :forbidden unless invitation.email.casecmp?(Current.user.email_address)

    invitation.accept!(Current.user)
    redirect_to invitation.team
  end
end
```

## Failure modes
Forged identifiers, wrong-purpose reuse, indefinite exposure, confused deputy behavior.

## Testing
Test tampering, wrong purpose, expiry, and successful validation.

## Review checklist
[ ] signature [ ] purpose [ ] expiry [ ] authorization

## Related skills
rails-serialization-globalid-engineering, rails-security-engineering, rails-authorization