---
name: broker-capacity
description: Model message arrival, consumer throughput, downstream limits, lag, and backpressure before changing messaging concurrency.
family: rails
---

# Broker Capacity

## Problem

Messaging can absorb bursts temporarily but cannot sustain an arrival rate above end-to-end consumer capacity.

## Use when

Changing message volume, consumer concurrency, partition count, retention, batch size, or retry behavior.

## Do not use when

The workload is trivially bounded and no meaningful broker or downstream capacity constraint exists.

## Repository inspection

Inspect arrival rate, burst rate, message size, retention, partitions/shards, consumer throughput, database pools, external API quotas, memory, CPU, and retry amplification.

## Implementation procedure

1. Measure arrival and processing rates.
2. Identify the slowest downstream capacity boundary.
3. Estimate queue/lag growth under burst and sustained load.
4. Bound consumer concurrency and batch size.
5. Protect dependencies with backpressure and rate limits.
6. Separate poison/retry traffic when necessary.
7. Monitor oldest-message age, not only depth.
8. Define scaling and degradation triggers.

## Example

```ruby
# Capacity check from measured numbers: sustained arrival rate must stay
# below what the consumers can process, or lag grows without bound.
arrival_per_second = 1_200.0   # p95 publish rate from the broker metrics
handler_seconds = 0.020        # p95 handler time per message
consumers = 16                 # partitions actually assigned

capacity_per_second = consumers / handler_seconds # => 800.0
headroom = capacity_per_second / arrival_per_second
puts format("capacity %.0f/s for %.0f/s arriving (%.2fx)", capacity_per_second, arrival_per_second, headroom)
# 0.67x: add partitions and consumers, or make the handler cheaper, before the next peak.
```

## Failure modes

- scaling consumers past database/API capacity
- retry amplification creating positive feedback
- large batches causing latency/memory spikes
- hot partition creating artificial capacity limits
- queue depth appears healthy while oldest messages are stale

## Testing

Load representative rates, measure lag and oldest-message age, verify dependency capacity, and test retry-storm behavior.

## Review checklist

- [ ] arrival rate known
- [ ] consumer throughput known
- [ ] bottleneck identified
- [ ] concurrency bounded
- [ ] retry amplification considered
- [ ] lag/age monitored
- [ ] degradation/scaling threshold defined

## Related skills

- rails-event-driven-messaging
- rails-performance
- ruby-concurrency
- rails-production-runtime

## Related patterns

- consumer-group-partitioning
- message-delivery-contract
