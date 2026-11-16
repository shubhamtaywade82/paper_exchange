---
name: secret-key-base-contract
description: Secret Key Base Contract
family: rails
---
# Secret Key Base Contract

## Problem
secret_key_base is a foundational Rails secret used by cryptographic features; careless overrides can invalidate sessions and other protected data.

## Use when
Changing secret_key_base storage, generation, or rotation.

## Do not use when
Changing unrelated credentials.

## Repository inspection
Inspect credentials, deployment variables, sessions/cookies, Active Storage usage, and rotation plan.

## Implementation procedure
Prefer credentials-backed secret_key_base in environments that require it; rotate with awareness of affected protected state.

## Example

```ruby
# secret_key_base derives keys for signed/encrypted cookies, sessions, message verifiers,
# Active Storage signed ids, and generates_token_for tokens.
Rails.application.secret_key_base # from credentials or SECRET_KEY_BASE; never logged

# Rotation without logging everyone out: keep accepting the old key for cookies.
Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
  old_secret = ENV.fetch("OLD_SECRET_KEY_BASE")
  key_generator = ActiveSupport::KeyGenerator.new(old_secret, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA256)
  cookies.rotate :encrypted, key_generator.generate_key("authenticated encrypted cookie", 32)
  cookies.rotate :signed, key_generator.generate_key("signed cookie")
end
# Remove the rotation after the longest cookie lifetime has elapsed.
```

## Failure modes
Hard-coded values, accidental regeneration, mass session invalidation without plan.

## Testing
Test boot, session continuity expectations, and rollback/rotation behavior.

## Review checklist
[ ] source explicit [ ] rotation impact known [ ] rollback plan

## Related skills
rails-encryption-credentials-engineering, rails-authentication, rails-production-runtime