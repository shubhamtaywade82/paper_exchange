---
name: active-storage-purge
description: Design safe Active Storage deletion, purge, and unattached-blob cleanup with bounded retention and reconciliation.
family: rails
---

# Active Storage Purge

## Problem

Deleting an attachment relationship and deleting the physical object are separate lifecycle operations.

## Use when

- removing files;
- implementing purge jobs;
- cleaning unattached direct uploads;
- changing retention behavior.

## Do not use when

- files must be retained permanently by policy and no cleanup is needed.

## Repository inspection

Inspect domain deletion semantics, purge jobs, Active Job queues, retention requirements, staged-upload workflows, object lifecycle policies, and metrics.

## Implementation procedure

1. Define retention policy.
2. Separate logical removal from physical purge.
3. Choose synchronous versus asynchronous cleanup.
4. Bound purge concurrency.
5. Define orphan-age threshold.
6. Add reconciliation metrics.
7. Test deletion failure and retry behavior.

## Example

```ruby
# Detach: remove the association; the blob and file stay (e.g. still
# referenced elsewhere or kept for audit).
user.avatar.detach

# Purge: delete the attachment record, the blob row, and the stored object.
# Done asynchronously because the storage call can be slow or fail.
user.avatar.purge_later

class User < ApplicationRecord
  # dependent: :purge_later is the default for has_one_attached; stated here
  # because account deletion relies on it.
  has_one_attached :avatar, dependent: :purge_later
end
```

## Failure modes

- destructive purge before business retention is satisfied;
- purging legitimate staged uploads;
- unbounded purge jobs;
- assuming object deletion succeeded because the database row disappeared;
- no reconciliation for storage drift.

## Testing

Test attachment removal, purge, storage failure, retry, orphan thresholds, and safe no-op behavior.

## Review checklist

- [ ] retention
- [ ] logical vs physical delete
- [ ] async semantics
- [ ] orphan threshold
- [ ] reconciliation
- [ ] failure handling

## Related skills

rails-active-storage, rails-active-job, rails-reliability-engineering, rails-database-engineering
