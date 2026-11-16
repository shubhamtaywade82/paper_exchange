---
name: eventual-consistency
description: Make asynchronous propagation and stale-read behavior explicit instead of pretending independent state is immediately consistent.
family: rails
---

# Eventual Consistency

## Problem

Independent components commit separately, so consumers may temporarily observe stale or incomplete state.

## Use when

Using asynchronous events, replicas, read models, caches, or separate service-owned data that converge over time.

## Do not use when

The user-visible contract requires immediate consistency and the architecture can enforce it synchronously.

## Repository inspection

Inspect source-of-truth ownership, propagation path, expected lag, read-after-write requirements, retry/replay behavior, reconciliation jobs, and API status semantics.

## Implementation procedure

1. Identify the authoritative source.
2. Define the maximum tolerated staleness or convergence expectation.
3. Define consumer states such as pending/ready/stale.
4. Document what a caller may observe during propagation.
5. Provide retry/replay/reconciliation for failed propagation.
6. Preserve monotonic or versioned state transitions where stale messages can arrive.
7. Surface pending/stale status instead of returning misleading certainty.
8. Instrument queue age and convergence lag.

## Example

```ruby
# The read model says what it knows and how fresh it is.
class SearchDocument < ApplicationRecord
  STALE_AFTER = 5.minutes

  def freshness
    return :pending if indexed_at.nil?
    source_updated_at > indexed_at || indexed_at < STALE_AFTER.ago ? :stale : :current
  end
end

# app/views/products/_search_status.html.erb renders "Updating…" for :pending/:stale.

# Reconciliation catches lost or delayed index updates.
class ReconcileSearchDocumentsJob < ApplicationJob
  def perform
    Product.where("updated_at > ?", 1.hour.ago).find_each do |product|
      doc = SearchDocument.find_by(product_id: product.id)
      next if doc && doc.source_updated_at >= product.updated_at

      IndexProductJob.perform_later(product.id)
    end
  end
end
```

## Failure modes

- exposing stale state as if current
- no convergence/reconciliation path
- out-of-order updates regress state
- synchronous API waits indefinitely for asynchronous propagation
- replica/read-model lag ignored
- cache invalidation assumed to imply global consistency

## Testing

Test stale reads, delayed events, duplicate/out-of-order delivery, propagation failure, reconciliation, and API behavior during pending state.

## Review checklist

- [ ] source of truth explicit
- [ ] consistency level explicit
- [ ] staleness bound/expectation defined
- [ ] pending/stale state modeled
- [ ] replay/reconciliation exists
- [ ] ordering/version handling exists
- [ ] API semantics match reality

## Related skills

- rails-distributed-systems
- rails-api-integration
- rails-observability
- rails-database-engineering
- rails-performance

## Related patterns

- message-delivery-contract
- inbox-deduplication
- outbox-publication
