---
name: data-repair-verification-contract
description: Data Repair Verification Contract
family: rails
---
# Data Repair Verification Contract

## Problem
A repair can run successfully at the process level while leaving incorrect data because success criteria are implicit.

## Use when
Backfills, repairs, reconciliation, or corrective scripts.

## Do not use when
Purely diagnostic commands that do not mutate state.

## Repository inspection
Inspect source-of-truth definition, repair predicate, expected postcondition, verification query, and rollback/reconciliation procedure.

## Implementation procedure
Define before/after invariants and execute an explicit verification step as part of the runbook or command output.

## Example

```ruby
# Repair with a stated postcondition, checked after the run.
namespace :repair do
  desc "Recompute order totals that drifted from their line items"
  task order_totals: :environment do
    drifted = Order.joins(:line_items).group(:id).having("orders.total_cents <> SUM(line_items.amount_cents)")
    puts "before: #{drifted.count.size} drifted orders"

    drifted.pluck(:id).each_slice(500) do |ids|
      Order.where(id: ids).find_each { |order| order.update_columns(total_cents: order.line_items.sum(:amount_cents)) }
    end

    remaining = drifted.count.size
    abort "postcondition failed: #{remaining} orders still drifted" unless remaining.zero?
    puts "after: 0 drifted orders"
  end
end
```

## Failure modes
False confidence from zero exceptions despite incorrect state.

## Testing
Test the verification query against good, bad, and partially repaired fixtures.

## Review checklist
[ ] source of truth [ ] postcondition [ ] verification query [ ] recovery

## Related skills
rails-operational-tasks-maintenance, rails-database-engineering