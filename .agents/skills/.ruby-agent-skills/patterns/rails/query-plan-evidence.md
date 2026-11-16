---
name: query-plan-evidence
description: Use execution-plan evidence to justify Rails database query and index performance changes.
family: rails
---

# Query Plan Evidence

## Problem

A Rails query is believed to be slow or inefficient, but the proposed fix is based on intuition rather than database execution evidence.

## Use when

Changing a query, scope, join, predicate, select list, or index because of measured database performance.

## Do not use when

The change is purely semantic or the query is not the measured bottleneck.

## Repository inspection

Inspect the Rails/adapter/database versions, exact generated SQL, existing indexes, representative table size/cardinality, query logs, and repository database tooling.

## Implementation procedure

1. Capture the exact query shape.
2. Measure baseline latency/query count.
3. Run the database's execution-plan tool.
4. Identify scans, joins, sorts, row estimates, and expensive operations.
5. Form one concrete hypothesis.
6. Make the smallest query/index change that addresses the evidence.
7. Re-run the plan.
8. Re-measure the workload.
9. Check write/storage trade-offs when indexes changed.

## Example

```bash
# Capture the plan for the exact query Rails sends, with real parameters, on production-like data.
bin/rails runner 'puts Order.where(account_id: 42, status: "pending").order(created_at: :desc).limit(20).explain(:analyze, :buffers)'

# Before (excerpt):
#   Seq Scan on orders  (actual time=0.03..812.4 rows=20 loops=1)
#     Filter: ((account_id = 42) AND (status = 'pending'))  Rows Removed by Filter: 2,413,870
# After add_index :orders, [:account_id, :status, :created_at], algorithm: :concurrently
#   Index Scan using index_orders_on_account_id_and_status_and_created_at  (actual time=0.04..0.21 rows=20)
```

## Failure modes

- adding an index without plan evidence
- optimizing a development-sized dataset
- trusting estimated rows without checking actual behavior
- fixing a SQL plan while increasing object materialization
- ignoring write amplification from indexes
- comparing plans from different workloads

## Testing

Preserve functional query tests and add/retain a performance check at the appropriate boundary. For index changes, verify the migration contract and representative query plan where infrastructure permits.

## Review checklist

- [ ] exact SQL identified
- [ ] baseline measured
- [ ] execution plan captured
- [ ] hypothesis tied to plan evidence
- [ ] new plan checked
- [ ] write/storage cost considered
- [ ] functional tests pass

## Related skills

- rails-performance
- rails-active-record
- rails-database-engineering
- ruby-performance
- rails-test-engineering
