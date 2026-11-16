---
name: idempotent-request
description: Make Rails API mutations safe across client retries, duplicate submissions, and ambiguous network outcomes.
family: rails
---

# Idempotent Request

## Problem

A client may submit the same mutation more than once because of retries, timeouts, or duplicate delivery.

## Use when

Designing mutation APIs where duplicate execution is materially harmful or expensive.

## Do not use when

The operation is read-only or duplicate execution is explicitly harmless.

## Repository inspection

Inspect request authentication, persistence, uniqueness constraints, transaction boundaries, existing idempotency keys, client conventions, and database version/adapter.

## Implementation procedure

1. Define idempotency-key scope.
2. Bind scope to principal/tenant where required.
3. Persist the key, request fingerprint, and result in a durable boundary.
4. Return the original outcome or an explicit conflict for duplicates.
5. Serialize concurrent duplicates using database/transaction boundaries.
6. Reject key reuse with different request semantics where required.
7. Define retention/expiry.
8. Test sequential and concurrent replay.

## Example

```ruby
class PaymentsController < ApplicationController
  def create
    key = request.headers["Idempotency-Key"].presence or return head(:bad_request)
    fingerprint = Digest::SHA256.hexdigest(payment_params.to_h.sort.to_json)

    record = IdempotencyKey.create_or_find_by!(account: Current.account, key:) do |k|
      k.request_fingerprint = fingerprint
    end
    return head(:unprocessable_entity) if record.request_fingerprint != fingerprint # key reused for a different body
    return render(json: record.response_body, status: record.response_status) if record.completed?

    payment = Current.account.payments.create!(payment_params)
    record.update!(response_status: 201, response_body: payment.as_json(only: %i[id amount_cents]), completed_at: Time.current)
    render json: record.response_body, status: :created
  end
end
# Unique index: add_index :idempotency_keys, %i[account_id key], unique: true
```

## Failure modes

- process-local idempotency state
- key not scoped to client/tenant
- side effect before idempotency state is committed
- inconsistent replay result
- same key accepted for different payloads
- assuming uniqueness validation alone creates idempotency

## Testing

Test first request, exact replay, same-key/different-payload, concurrent duplicate, failure-then-retry, and expiry behavior where applicable.

## Review checklist

- [ ] key scope explicit
- [ ] durable state
- [ ] fingerprint semantics explicit
- [ ] transaction boundary explicit
- [ ] duplicate result explicit
- [ ] concurrent duplicates tested
- [ ] retention policy defined

## Related skills

- rails-api-integration
- rails-database-engineering
- rails-security
- rails-test-engineering
- rails-active-job
