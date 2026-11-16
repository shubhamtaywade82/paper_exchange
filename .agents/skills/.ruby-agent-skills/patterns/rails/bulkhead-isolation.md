---
name: bulkhead-isolation
description: Isolate shared capacity so failure or saturation in one workload cannot exhaust resources required by another.
family: rails
---

# Bulkhead Isolation

## Problem

Independent workloads share threads, connections, queues, or memory, so one overloaded dependency can starve critical work.

## Use when

A shared resource has identifiable workload classes or failure domains that require independent capacity.

## Do not use when

There is no meaningful shared resource or the repository's existing pool/queue boundary already isolates the workloads.

## Repository inspection

Inspect resource pools, worker topology, traffic classes, dependency domains, CPU/memory, connection limits, and existing queue isolation.

## Implementation procedure

1. Identify the shared resource.
2. Identify which workloads must be protected.
3. Allocate bounded capacity per class.
4. Define rejection/queueing behavior.
5. Monitor saturation per class.
6. Test one class exhausting capacity while another remains functional.
7. Revisit capacity fragmentation from measured utilization.

## Example

```ruby
# config/queue.yml (Solid Queue): critical work gets its own workers, so a
# backlog of slow report jobs cannot starve payments.
#
# production:
#   workers:
#     - queues: [payments]
#       threads: 5
#       processes: 2
#     - queues: [reports, exports]
#       threads: 2
#       processes: 1

class ChargeJob < ApplicationJob
  queue_as :payments
end

class MonthlyReportJob < ApplicationJob
  queue_as :reports
end
```

## Failure modes

- no real isolation
- too-small pools cause underutilization
- too many pools fragment capacity
- protected pool still shares a constrained downstream dependency
- silent starvation of low-priority work

## Testing

Exhaust one workload's capacity and verify protected workloads retain their contract. Test recovery and queue behavior.

## Review checklist

- [ ] shared resource identified
- [ ] protected class explicit
- [ ] capacity bounded
- [ ] rejection behavior explicit
- [ ] isolation tested
- [ ] fragmentation considered

## Related skills

- rails-reliability-engineering
- ruby-concurrency
- rails-performance
- rails-production-runtime
