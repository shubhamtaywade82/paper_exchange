---
name: globalid-resolution-failure-contract
description: Global ID Resolution Failure Contract
family: rails
---
# Global ID Resolution Failure Contract

## Problem
Missing records and temporary backend failures require different operational responses.

## Use when
Resolving Global IDs in jobs or distributed workflows.

## Do not use when
A local identity lookup that cannot encounter persistence/backend failure.

## Repository inspection
Inspect locate versus fetch behavior, retry/discard policy, record lifecycle, and backend reliability.

## Implementation procedure
Distinguish malformed IDs, deleted records, and unavailable backends; map each to explicit retry/discard/reconcile behavior.

## Example

```ruby
class SyncInvoiceJob < ApplicationJob
  # Record deleted after enqueue: permanent, drop with a log line.
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.info(event: "sync_invoice.discarded", job_id: job.job_id,
                      reason: error.cause&.class&.name)
  end

  # Database unavailable while resolving the GlobalID: transient, retry bounded.
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 5

  def perform(invoice)
    BillingProvider.sync(invoice)
  end
end
```

## Failure modes
Transient outages discarded as permanent failures, deleted records retried forever, generic rescue hides incidents.

## Testing
Test each failure class independently.

## Review checklist
[ ] malformed [ ] not found [ ] unavailable [ ] retry/discard

## Related skills
rails-serialization-globalid-engineering, rails-reliability-engineering, rails-active-job