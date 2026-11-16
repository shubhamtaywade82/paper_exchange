---
name: operational-observability-contract
description: Operational Observability Contract
family: rails
---
# Operational Observability Contract

## Problem
Operators cannot safely verify progress or outcome when maintenance tasks emit insufficient or unsafe diagnostics.

## Use when
Tasks with significant duration, blast radius, or recovery implications.

## Do not use when
Tiny local-only tasks where ordinary command output is sufficient.

## Repository inspection
Inspect logging conventions, metrics/instrumentation, runbooks, and sensitive-field rules.

## Implementation procedure
Report bounded counts, progress, failures, duration, and final state without secret or high-cardinality payloads.

## Example

```ruby
namespace :search do
  desc "Reindex products"
  task reindex: :environment do
    run_id = SecureRandom.uuid
    total = Product.count
    processed = failed = 0
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Product.find_in_batches(batch_size: 500) do |batch|
      batch.each do |product|
        SearchIndex.upsert(product)
        processed += 1
      rescue SearchIndex::Error => e
        failed += 1
        Rails.logger.warn(event: "reindex.failed", run_id:, product_id: product.id, error: e.class.name)
      end
      Rails.logger.info(event: "reindex.progress", run_id:, processed:, failed:, total:)
    end
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
    Rails.logger.info(event: "reindex.finished", run_id:, processed:, failed:, total:, seconds: elapsed)
    exit 1 if failed.positive?
  end
end
```

## Failure modes
No evidence of progress, misleading success, secret leakage, or unusably noisy logs.

## Testing
Test output for expected milestones and absence of sensitive values.

## Review checklist
[ ] progress [ ] final summary [ ] exit semantics [ ] secret-safe

## Related skills
rails-operational-tasks-maintenance, rails-observability