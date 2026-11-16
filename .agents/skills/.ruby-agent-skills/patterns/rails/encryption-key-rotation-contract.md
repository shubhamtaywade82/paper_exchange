---
name: encryption-key-rotation-contract
description: Encryption Key Rotation Contract
family: rails
---
# Encryption Key Rotation Contract

## Problem
Changing cryptographic keys can make existing protected data unreadable unless old/new compatibility is deliberately managed.

## Use when
Rotating credential or Active Record Encryption keys.

## Do not use when
Generating an initial key set for a new application.

## Repository inspection
Inspect key providers, rotation APIs, deployment overlap, old-data compatibility, background jobs, and rollback plan.

## Implementation procedure
Introduce the new key in a controlled overlap, support reads of existing data as required, re-encrypt deterministically, then retire old material.

## Example

```ruby
# credentials: active_record_encryption.primary_key is a list; the LAST key
# encrypts new data, all keys can decrypt.
#   active_record_encryption:
#     primary_key:
#       - <old key>
#       - <new key>
Rails.application.config.active_record.encryption.store_key_references = true

# Re-encrypt existing rows with the new key, resumably, then drop the old key.
Patient.find_each(batch_size: 500, &:encrypt)
```

## Failure modes
Data unreadability, split-brain deployments, failed jobs, or premature removal of old keys.

## Testing
Test old/new reads, writes, mixed-version deployment behavior, and final retirement.

## Review checklist
[ ] overlap plan [ ] old reads [ ] new writes [ ] migration complete [ ] retirement

## Related skills
rails-encryption-credentials-engineering, rails-production-runtime, rails-reliability-engineering