---
name: master-key-boundary
description: Master Key Boundary
family: rails
---
# Master Key Boundary

## Problem
The credential ciphertext can be public while the decryption key must remain secret and tightly controlled.

## Use when
Changing config/master.key, environment key delivery, or require_master_key.

## Do not use when
Changing unrelated non-secret configuration.

## Repository inspection
Inspect repository ignore rules, deployment secret injection, CI variables, containers, and boot configuration.

## Implementation procedure
Keep key files out of source distribution; inject required keys through the approved deployment mechanism; fail closed when required.

## Example

```bash
# Committed: config/credentials.yml.enc (ciphertext).
# Never committed: config/master.key (listed in .gitignore by the Rails generator).
git check-ignore -q config/master.key || { echo "master.key is not ignored" >&2; exit 1; }

# Runtime: the key arrives from the platform secret store, not the image.
kamal secrets print | grep -q RAILS_MASTER_KEY || echo "RAILS_MASTER_KEY missing from .kamal/secrets"

# Fail closed: production refuses to boot without the key.
grep -q "config.require_master_key = true" config/environments/production.rb
```

## Failure modes
Leaked master keys, secrets embedded in images, permissive file access, or silent boot fallback.

## Testing
Test production-like boot with and without the required key.

## Review checklist
[ ] key absent from Git [ ] runtime delivery [ ] fail-closed behavior [ ] access reviewed

## Related skills
rails-encryption-credentials-engineering, rails-production-runtime, rails-security-engineering