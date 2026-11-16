---
name: credentials-store-contract
description: Credentials Store Contract
family: rails
---
# Credentials Store Contract

## Problem
Secret material is unsafe when storage, key ownership, and runtime access are implicit.

## Use when
Adding or changing Rails credentials.

## Do not use when
The value is non-sensitive application configuration.

## Repository inspection
Inspect credential paths, key files, deployment secret injection, environment conventions, and existing access patterns.

## Implementation procedure
Choose a supported encrypted credential store or approved runtime secret source; document owner and access path.

## Example

```ruby
# Where each kind of secret lives, and who can read it:
#   application secrets     -> Rails credentials (encrypted, key held by deploy system)
#   master key              -> RAILS_MASTER_KEY in the deploy secret store, never in git
#   per-customer API tokens -> database, as SHA-256 digests only
#   Active Record Encryption keys -> credentials under active_record_encryption
module Secrets
  def self.stripe_key = Rails.application.credentials.fetch(:stripe).fetch(:secret_key)
end
```

## Failure modes
Plaintext Git secrets, leaked key files, undocumented alternate stores.

## Testing
Test credential access using non-production values and verify missing-key behavior.

## Review checklist
[ ] store explicit [ ] key separate [ ] access path documented

## Related skills
rails-encryption-credentials-engineering, rails-security-engineering