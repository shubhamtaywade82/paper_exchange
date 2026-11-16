---
name: action-cable-capacity
description: Size Rails Action Cable connections, subscriptions, broadcast fan-out, serialization, Redis, and reconnect load.
family: rails
---

# Action Cable Capacity

## Problem

WebSocket systems consume persistent memory and pub/sub/network capacity even when HTTP traffic is low.

## Use when

- adding high-frequency realtime features;
- changing deployment scale or Redis;
- diagnosing reconnect/fan-out overload.

## Do not use when

- realtime traffic is trivial and the existing measured capacity envelope is unchanged.

## Repository inspection

Inspect active connections, subscriptions, message rate, payload size, Redis throughput, process memory, CPU, network egress, and reconnect rates.

## Implementation procedure

1. Estimate connection count.
2. Estimate subscriptions per connection.
3. Estimate messages/second.
4. Estimate bytes/second.
5. Measure serialization cost.
6. Bound fan-out.
7. Model reconnect bursts.
8. Validate against process/Redis/network capacity.

## Example

```ruby
# config/cable.yml sizes the pub/sub backend separately from HTTP, and the
# server bounds its worker pool; connection counts are measured, not guessed.
#
# production:
#   adapter: redis
#   url: <%= ENV.fetch("REDIS_CABLE_URL") %>
#   channel_prefix: myapp_production

Rails.application.configure do
  config.action_cable.worker_pool_size = Integer(ENV.fetch("CABLE_WORKER_POOL", "4"))
  config.action_cable.allowed_request_origins = [ENV.fetch("APP_ORIGIN")]
end

ActiveSupport::Notifications.subscribe("perform_action.action_cable") do |event|
  StatsD.histogram("cable.action.duration", event.duration, tags: ["channel:#{event.payload[:channel_class]}"])
end
```

## Failure modes

- sizing from HTTP QPS alone;
- hot broadcast fan-out;
- large payloads;
- reconnect storm;
- Redis saturation;
- per-process memory exhaustion.

## Testing

Load-test representative connection/fan-out shapes and verify bounds.

## Review checklist

- [ ] connection count
- [ ] subscriptions
- [ ] message/byte rate
- [ ] serialization
- [ ] Redis
- [ ] memory/CPU
- [ ] reconnect burst

## Related skills

rails-action-cable, rails-production-runtime, rails-performance, ruby-performance, ruby-concurrency, rails-reliability-engineering
