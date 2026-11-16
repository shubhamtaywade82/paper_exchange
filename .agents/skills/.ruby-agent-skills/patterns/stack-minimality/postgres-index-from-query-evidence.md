---
name: postgres-index-from-query-evidence
description: PostgreSQL Index From Query Evidence
family: stack-minimality
---
# PostgreSQL Index From Query Evidence

## Problem
Indexes add storage, write, maintenance, and planner costs.

## Use when
Optimizing a PostgreSQL query, endpoint, report, or job.

## Do not use when
A constraint already requires an index or the required index is already present.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Inspect query shape, cardinality, existing indexes, and representative plans. Add the smallest index that serves the actual predicate/order/join shape.

## Example

```sql
-- 1. Evidence: the real query, with the plan and buffers, on production-like data.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, total_cents FROM orders
WHERE tenant_id = 42 AND status = 'open'
ORDER BY created_at DESC
LIMIT 20;
-- Seq Scan on orders ... rows removed by filter: 1,904,311 ... Execution Time: 812 ms

-- 2. The index that matches the filter and sort, built without blocking writes.
CREATE INDEX CONCURRENTLY index_orders_on_tenant_status_created
  ON orders (tenant_id, status, created_at DESC);

-- 3. Re-run the same EXPLAIN (ANALYZE, BUFFERS) and keep both plans as evidence.
```

## Failure modes
Indexing by column intuition, duplicate indexes, and unmeasured performance claims.

## Testing
Use real EXPLAIN ANALYZE and migration verification.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
rails-database-engineering, rails-performance, stack-minimality-evidence, stack-minimality
