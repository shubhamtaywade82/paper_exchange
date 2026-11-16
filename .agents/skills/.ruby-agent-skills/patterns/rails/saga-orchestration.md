---
name: saga-orchestration
description: Coordinate a multi-transaction business workflow with explicit state, compensation, retry, and recovery.
family: rails
---

# Saga Orchestration

## Problem

A business workflow spans independent transaction owners, so no single database transaction can atomically commit the full operation.

## Use when

Multiple services/datastores own separate steps and partial completion must be recovered explicitly.

## Do not use when

A single database transaction can own the invariant or a simpler asynchronous workflow is sufficient.

## Repository inspection

Inspect transaction owners, command/event contracts, workflow persistence, timeouts, retries, compensation behavior, dead-letter/replay tooling, and operator recovery.

## Implementation procedure

1. Define the workflow state machine.
2. Define each step's forward action and success state.
3. Persist durable workflow state.
4. Define timeout and retry policy per step.
5. Define compensating action or explicit manual recovery.
6. Make every step idempotent.
7. Record correlation/causation identifiers.
8. Expose failure/replay state to operators.
9. Test partial completion and recovery.

## Example

```ruby
# Orchestrated saga: each step is a local transaction with a compensation; state is durable.
class TripBookingSaga < ApplicationRecord # columns: status, flight_ref, hotel_ref, step
  STEPS = [
    [:reserve_flight, :cancel_flight],
    [:reserve_hotel, :cancel_hotel],
    [:charge_card, :refund_card]
  ].freeze

  def run!
    STEPS.each_with_index do |(action, _), index|
      next if step > index # resume after a crash
      send(action)
      update!(step: index + 1)
    end
    update!(status: "completed")
  rescue Booking::PermanentError
    compensate!
  end

  private

  def compensate!
    STEPS.first(step).reverse_each { |(_, undo)| send(undo) } # each undo is idempotent
    update!(status: "compensated")
  end

  def reserve_flight = update!(flight_ref: Flights.reserve(trip_id: id, key: "trip-#{id}-flight"))
  def reserve_hotel = update!(hotel_ref: Hotels.reserve(trip_id: id, key: "trip-#{id}-hotel"))

  def cancel_flight
    Flights.cancel(flight_ref) if flight_ref
  end

  def cancel_hotel
    Hotels.cancel(hotel_ref) if hotel_ref
  end

  def charge_card = Payments.charge(trip_id: id, key: "trip-#{id}-charge")
  def refund_card = Payments.refund(key: "trip-#{id}-charge")
end
```

## Failure modes

- saga used where one local transaction suffices
- compensation assumed to be an exact rollback
- step not idempotent
- workflow state kept only in memory
- infinite retry of an unavailable service
- compensation failure with no recovery path
- hidden coupling through shared database state

## Testing

Test success, timeout, retry, partial completion, duplicate command, compensation success/failure, and replay/resume from persisted state.

## Review checklist

- [ ] independent transaction owners justify saga
- [ ] durable state machine
- [ ] step idempotency
- [ ] compensation semantics explicit
- [ ] bounded retries/timeouts
- [ ] recovery/replay path
- [ ] observability/correlation

## Related skills

- rails-distributed-systems
- rails-active-job
- rails-api-integration
- rails-database-engineering
- rails-observability

## Related patterns

- transaction-boundary
- idempotent-job
- message-delivery-contract
