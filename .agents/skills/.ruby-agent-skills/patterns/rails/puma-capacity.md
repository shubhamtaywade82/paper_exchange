---
name: puma-capacity
description: Size Puma workers and threads against CPU, memory, database pool, and downstream capacity.
family: rails
---

# Puma Capacity

## Problem
Puma concurrency settings create aggregate CPU, memory, database, and dependency load.

## Use when
Changing workers, threads, WEB_CONCURRENCY, RAILS_MAX_THREADS, or production request capacity.

## Implementation procedure
1. Inspect CPU and memory limits.
2. Determine current workers and threads.
3. Determine database pool and downstream limits.
4. Estimate aggregate concurrency.
5. Change one capacity dimension.
6. Measure request latency, queueing, memory, CPU, and DB pool pressure.
7. Retune using evidence.

## Example

```ruby
# config/puma.rb
# Sizing (per 2 vCPU / 4 GB container, measured RSS ≈ 450 MB/worker):
#   workers 2 × threads 5 = 10 concurrent requests per container
#   DB connections: 2 workers × 5 threads = 10 per container (pool: 5 per process)
#   8 containers × 10 = 80 connections  ≤  PostgreSQL max_connections 200 − jobs 40 − admin 10
workers Integer(ENV.fetch("WEB_CONCURRENCY", 2))
max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
threads max_threads, max_threads
preload_app!
port Integer(ENV.fetch("PORT", 3000))

# config/database.yml: pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
```

## Failure modes
- threads exceed database capacity
- workers exceed memory budget
- optimizing CPU while requests are DB-bound
- using generic worker counts without workload evidence

## Testing
Run production-like load/capacity checks where available.

## Review checklist
- CPU budget known
- memory budget known
- DB budget known
- downstream limits considered
- change is measured


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when Puma capacity is not being changed and there is no measured production runtime capacity problem.
