---
name: performance-investigation
description: Investigate a measured Ruby/Rails performance problem from workload and baseline through profiling, hypothesis, targeted change, and remeasurement.
family: performance
---

# Performance Investigation

## Problem

A concrete workload is slower, more memory-intensive, more allocation-heavy, or lower-throughput than required.

## Use when

Use after a performance symptom or explicit measurable target exists.

## Do not use when

Do not use as justification for speculative refactoring or generic micro-optimization.

## Implementation procedure

1. Define workload and target.
2. Establish a reproducible baseline.
3. Measure the relevant dimension.
4. Profile or instrument the dominant path.
5. Identify the application-owned bottleneck.
6. Form one optimization hypothesis.
7. Change the smallest relevant surface.
8. Run functional tests.
9. Re-measure.
10. Compare relevant dimensions.
11. Keep only evidence-backed improvements.

## Testing

Use functional regression tests plus a stable performance contract when the repository has one.

## Review checklist

- baseline exists
- workload is representative
- bottleneck is measured
- optimization has a hypothesis
- behavior remains correct
- result is re-measured
- trade-offs documented

## Related skills

- ruby-performance
- ruby-concurrency
- rails-active-record
- rails-test-engineering
- ruby-tdd-refactoring


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.

## Example

```ruby
require "benchmark"
require "memory_profiler"

# Reproduce the slow workload, measure it, change one thing, measure again.
orders = Order.includes(:line_items).where(created_at: 30.days.ago..).to_a

before = Benchmark.realtime { orders.map { |order| order.line_items.map(&:amount_cents).sum } }
after = Benchmark.realtime { orders.sum { |order| order.line_items.sum(&:amount_cents) } }
puts format("before %.3fs  after %.3fs", before, after)

report = MemoryProfiler.report { orders.sum { |order| order.line_items.sum(&:amount_cents) } }
puts "allocated objects: #{report.total_allocated}"
```

## Failure modes

- optimizing a non-bottleneck
- changing workload between baseline and comparison
- retaining an optimization that regresses another critical dimension
