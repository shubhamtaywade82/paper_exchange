---
name: partial-failure-contract
description: Operational Partial Failure Contract
family: rails
---
# Operational Partial Failure Contract

## Problem
Long maintenance runs can leave a mixed state when some records fail and error policy is implicit.

## Use when
Tasks processing many independent records.

## Do not use when
Atomic operations where any failure must roll back everything.

## Repository inspection
Inspect dependency failures, retry semantics, error reporting, and operator recovery workflow.

## Implementation procedure
Choose fail-fast, collect-and-report, selective retry, or reconciliation semantics and make them visible in the final result.

## Example

```ruby
# Policy: collect-and-report. One bad record does not stop the run; the exit status
# and failure file make the mixed state explicit and rerunnable.
namespace :catalog do
  task reprice: :environment do
    failures = []
    Product.where(repriced_at: nil).find_each do |product|
      product.reprice!
    rescue ActiveRecord::RecordInvalid, Pricing::Error => e
      failures << { id: product.id, error: e.class.name }
    end

    path = Rails.root.join("tmp/reprice_failures_#{Time.current.to_i}.json")
    File.write(path, JSON.pretty_generate(failures))
    puts "failed=#{failures.size} (details: #{path}); rerun processes only unrepriced products"
    exit 1 if failures.any?
  end
end
```

## Failure modes
Silent skipped records, endless retries, false success, or incomplete reporting.

## Testing
Inject representative failures and verify reported and persisted outcomes.

## Review checklist
[ ] failure policy [ ] visible result [ ] retry/reconcile [ ] exit status

## Related skills
rails-operational-tasks-maintenance, rails-reliability-engineering