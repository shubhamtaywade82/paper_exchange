---
name: connection-pool-capacity
description: Size and diagnose Rails database connection pools against aggregate web/job concurrency and database limits.
family: rails
---

# Connection Pool Capacity

## Problem

Rails concurrency is changed or pool exhaustion occurs, but the application only considers one process rather than aggregate connection demand.

## Use when

Changing Puma threads, job worker concurrency, database pool size, multiple roles/shards, or diagnosing connection checkout timeouts.

## Do not use when

No database concurrency or connection capacity is involved.

## Repository inspection

Inspect Rails configuration, Puma/worker topology, Active Job worker topology, database roles/shards, pool settings, database max connections, long transactions, and observed checkout/timeout metrics.

## Implementation procedure

1. Enumerate application processes.
2. Determine concurrency per process.
3. Determine connection demand per concurrent execution path.
4. Compare aggregate demand with pool and database limits.
5. Identify long-held connections and slow queries.
6. Change one capacity dimension.
7. Measure checkout wait, query latency, memory, CPU, and database pressure.

Use aggregate reasoning:

~~~text
web processes × web concurrency
+
job processes × job concurrency
+
other database clients
≤
database connection budget
~~~

Treat the inequality as a capacity model, not a promise that every thread always owns a connection.

## Example

```ruby
# Aggregate demand across every process, not one pool at a time:
web_processes = 2 * 4        # 2 servers x WEB_CONCURRENCY 4
web_threads = 5              # RAILS_MAX_THREADS
job_processes = 3
job_threads = 10
headroom = 10                # migrations, console, cron

demand = (web_processes * web_threads) + (job_processes * job_threads) + headroom # => 80
postgres_max_connections = 100
puts "#{demand} of #{postgres_max_connections} connections"

# database.yml: pool must be >= the threads of the process using it.
#   production:
#     pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
```

## Failure modes

- increasing pool until the database saturates
- sizing only one process
- ignoring job workers
- ignoring multiple roles/shards
- using large pools to hide slow queries
- confusing thread count with connection usage
- starving the pool with long transactions

## Testing

Use repository load/capacity checks where available. Add configuration/contract tests for derived concurrency assumptions rather than hard-coded timing checks.

## Review checklist

- [ ] topology enumerated
- [ ] aggregate demand modeled
- [ ] database limit known
- [ ] long-held connections investigated
- [ ] query latency considered
- [ ] memory/CPU impact considered
- [ ] capacity change measured

## Related skills

- rails-performance
- rails-database-engineering
- rails-production-runtime
- rails-active-job
- ruby-concurrency
- ruby-performance
