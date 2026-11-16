---
name: association-counter-touch-contract
description: Use when adding counter_cache or touch and the association creates denormalized lifecycle or timestamp coupling.
family: rails
---

# Association Counter Cache and Touch

## Problem

Counter caches and touch propagate association changes into denormalized columns and can create write amplification or stale derived values.

## Use when

- adding or changing counter_cache
- adding touch
- debugging stale counts or timestamp-driven cache invalidation.

## Do not use when

- no denormalized association metadata changes.

## Repository inspection

Inspect authoritative count logic, association mutation paths, cache keys, timestamps, bulk operations, and reconciliation jobs.

## Implementation procedure

1. Define the authoritative source of truth.
2. Identify every mutation path that updates the derived value.
3. Verify bulk operations and direct SQL do not silently bypass the contract.
4. Define repair/reconciliation behavior.
5. Measure write amplification where material.

## Example

```ruby
class Comment < ApplicationRecord
  # comments_count is denormalized; its authoritative source is the rows.
  belongs_to :post, counter_cache: true, touch: :last_commented_at
end

# Reconcile after bulk writes or imports that bypass callbacks:
Post.where(id: affected_post_ids).find_each { |post| Post.reset_counters(post.id, :comments) }
```

## Failure modes

- treating counter cache as immutable truth
- stale counts after bulk operations
- touch cascades causing write storms
- cache invalidation coupled to incidental child updates.

## Testing

Test create/delete/update paths, bulk changes where relevant, and repair/reconciliation behavior.

## Review checklist

- [ ] source of truth is explicit
- [ ] mutation paths are complete
- [ ] bulk bypasses are understood
- [ ] write amplification is acceptable

## Related skills

rails-associations, rails-active-record, rails-caching, rails-performance, rails-database-engineering
