---
name: distributed-service-boundary
description: Define an explicit ownership and communication boundary between independently deployed or persisted components.
family: rails
---

# Distributed Service Boundary

## Problem

A workflow crosses an independent process, service, datastore, or trust boundary, but ownership and failure semantics remain implicit.

## Use when

A Rails application is extracting a service, calling an independently deployed component, or splitting ownership of domain behavior.

## Do not use when

The collaborators are in the same process and the correctness invariant can remain inside one application/module boundary.

## Repository inspection

Inspect service deployment topology, database ownership, API/message contracts, authentication, timeout/retry behavior, data replication, observability, and rollout sequencing.

## Implementation procedure

1. Name the owner of each domain invariant.
2. Define the public command/query/event contract.
3. Identify synchronous versus asynchronous communication.
4. Define source-of-truth and read-model responsibilities.
5. Define timeout, retry, and duplicate behavior.
6. Define correlation and failure reporting.
7. Define old/new compatibility for rolling deployment.
8. Test dependency failure and contract compatibility.

## Example

```ruby
# Calling another service: explicit owner, timeout, idempotency key, and a
# defined behaviour when the call's outcome is unknown.
class Fulfillment::Client
  def ship(order)
    response = @http.post("/v1/shipments", { order_id: order.id, items: order.skus },
                          "Idempotency-Key" => "ship-#{order.id}", timeout: 3)
    order.update!(shipment_id: response.fetch("id"), status: "shipping")
  rescue Faraday::TimeoutError
    # Unknown outcome: do not retry blindly; reconcile via GET /v1/shipments?order_id=
    ReconcileShipmentJob.set(wait: 1.minute).perform_later(order.id)
  end
end
```

## Failure modes

- shared database creating hidden ownership
- duplicate invariant enforcement in multiple services
- synchronous call chains that amplify outages
- provider-specific schema leaking into the domain
- no owner for reconciliation
- contract changes deployed without consumer compatibility

## Testing

Test contract shape, dependency failure, timeout, retry, duplicate request/event behavior, and old/new schema compatibility where both versions can coexist.

## Review checklist

- [ ] ownership is explicit
- [ ] authoritative writer is explicit
- [ ] communication semantics are explicit
- [ ] failure behavior is bounded
- [ ] observability crosses the boundary
- [ ] rollout compatibility exists

## Related skills

- rails-distributed-systems
- rails-api-integration
- rails-database-engineering
- rails-observability
- rails-production-runtime

## Related patterns

- api-contract-versioning
- message-delivery-contract
