---
name: consumer-group-partitioning
description: Choose message partitioning, routing keys, consumer groups, and concurrency around ordering and downstream capacity.
family: rails
---

# Consumer Group & Partitioning

## Problem

Increasing message-consumer parallelism can violate ordering or overload downstream resources.

## Use when

Designing queues/topics/streams with multiple consumers or changing partition/routing-key strategy.

## Do not use when

A single-worker queue already owns the required ordering and no parallelism decision exists.

## Repository inspection

Inspect transport partition/shard semantics, ordering guarantees, key distribution, worker count, database pools, dependency limits, and rebalance behavior.

## Implementation procedure

1. Identify the entity whose transitions require ordering.
2. Choose the narrowest routing/partition key preserving that ordering.
3. Measure key distribution and hot-key risk.
4. Match consumer count to partition/shard parallelism.
5. Size downstream database/API capacity.
6. Define shutdown and rebalance behavior.
7. Test conflicting same-key messages and independent-key concurrency.
8. Monitor lag and skew.

## Example

```ruby
# Messages for one account share a partition key, so they are processed in
# order by one consumer; different accounts proceed in parallel.
class AccountEventPublisher
  def publish(event)
    Kafka.producer.produce(event.to_json, topic: "account-events", partition_key: event.fetch(:account_id).to_s)
  end
end
# Consumers in the group <= partitions; more consumers than partitions sit idle.
```

## Failure modes

- global ordering bottleneck
- hot partition
- consumers exceed downstream capacity
- consumer count exceeds useful partition parallelism
- ordering broken by an inconsistent key
- rebalancing causes duplicate work

## Testing

Test same-key ordering, independent-key parallelism, skew/hot-key behavior, consumer restart, and duplicate delivery during rebalancing.

## Review checklist

- [ ] ordering entity identified
- [ ] key strategy justified
- [ ] hot-key risk measured
- [ ] consumer count bounded
- [ ] downstream capacity checked
- [ ] rebalance semantics tested

## Related skills

- rails-event-driven-messaging
- rails-distributed-systems
- ruby-concurrency
- rails-performance
- rails-production-runtime

## Related patterns

- message-delivery-contract
- inbox-deduplication
- broker-capacity
