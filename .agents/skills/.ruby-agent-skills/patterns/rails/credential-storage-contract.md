---
name: credential-storage-contract
description: Define safe password and long-lived credential storage, comparison, filtering, rotation, and migration behavior.
family: rails
---

# Credential Storage Contract

## Problem

Credential handling failures often come from plaintext storage, weak comparison, leaked logs, missing rotation, or schema changes that break authentication.

## Use when

Changing password storage, password hashing, API tokens, reset tokens, credential fields, or credential migrations.

## Do not use when

Changing non-secret profile fields without authentication semantics.

## Repository inspection

Inspect hashing library, credential model, digest columns, normalization, logging filters, token tables, indexes, secrets management, and migration compatibility.

## Implementation procedure

1. Classify the credential type.
2. Identify the authoritative hash/digest mechanism.
3. Verify credentials are never stored plaintext.
4. Verify comparison uses the framework/library primitive.
5. Filter secret parameters and logs.
6. Define rotation/revocation semantics.
7. Preserve old/new schema compatibility during migration.
8. Add tests that prove secrets are not exposed.

## Example

```ruby
class User < ApplicationRecord
  # bcrypt digest (has_secure_password); the plaintext is never stored or logged.
  has_secure_password
  validates :password, length: { minimum: 12 }, allow_nil: true
end

class ApiToken < ApplicationRecord
  # Only a SHA-256 digest of the token is stored; the raw token is shown once.
  def self.issue!(user)
    raw = SecureRandom.urlsafe_base64(32)
    create!(user: user, token_digest: Digest::SHA256.hexdigest(raw))
    raw
  end

  def self.find_by_token(raw)
    find_by(token_digest: Digest::SHA256.hexdigest(raw.to_s))
  end
end

Rails.application.config.filter_parameters += %i[password token]
```

## Failure modes

- plaintext password
- raw bearer/reset token persisted unnecessarily
- secrets logged
- credential migration leaves two sources of truth
- hash algorithm changed without compatibility or upgrade path

## Testing

Test valid/invalid credential checks, migration behavior, log filtering, and revocation.

## Review checklist

- [ ] no plaintext secret storage
- [ ] safe comparison primitive
- [ ] logging filtered
- [ ] rotation/revocation explicit
- [ ] migration path documented

## Related skills

- rails-authentication
- rails-active-record
- rails-security
- rails-database-engineering

