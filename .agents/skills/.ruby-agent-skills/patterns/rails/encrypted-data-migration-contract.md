---
name: encrypted-data-migration-contract
description: Encrypted Data Migration Contract
family: rails
---
# Encrypted Data Migration Contract

## Problem
Converting existing plaintext data can create partial encryption, downtime, irreversible loss, or mixed-format ambiguity.

## Use when
Migrating an existing persisted field to or between encrypted formats.

## Do not use when
A brand-new field with no existing data.

## Repository inspection
Inspect row counts, nullability, indexes, write paths, deployment sequencing, backups, and rollback capabilities.

## Implementation procedure
Use expand/transform/verify/cutover sequencing; make the transformation resumable and observable; preserve recovery evidence.

## Example

```ruby
# Step 1 (deploy): declare encryption while still reading plaintext.
#   config.active_record.encryption.support_unencrypted_data = true
#   class Patient < ApplicationRecord; encrypts :notes; end
#
# Step 2 (resumable backfill): encrypt existing rows in batches.
Patient.where(notes_encrypted_at: nil).in_batches(of: 1_000) do |batch|
  batch.each(&:encrypt)
  batch.update_all(notes_encrypted_at: Time.current)
end
#
# Step 3 (verify, then deploy): every row encrypted, then turn off
# support_unencrypted_data so plaintext is rejected.
abort "unencrypted rows remain" if Patient.where(notes_encrypted_at: nil).exists?
```

## Failure modes
Partial conversion, dual-write drift, lost plaintext before verification, or rollback impossibility.

## Testing
Test on realistic fixtures and execute a representative migration/verification flow.

## Review checklist
[ ] expand first [ ] transform resumable [ ] verify [ ] recovery evidence [ ] cutover

## Related skills
rails-encryption-credentials-engineering, rails-database-engineering, rails-reliability-engineering