---
name: webhook-ingestion
description: Build replay-safe Rails webhook endpoints with authenticity verification, durable receipt state, and explicit acknowledgement semantics.
family: rails
---

# Webhook Ingestion

## Problem

A provider sends untrusted callbacks that may be duplicated, delayed, reordered, or retried.

## Use when

Adding or reviewing webhook endpoints, event receivers, callback controllers, or provider push notifications.

## Do not use when

The endpoint is an ordinary authenticated request without provider-driven delivery semantics.

## Repository inspection

Inspect provider signature rules, canonical signing input, secret storage, webhook route/controller, event IDs, deduplication storage, Active Job conventions, and request tests.

## Implementation procedure

1. Receive the provider request.
2. Verify authenticity using the required representation.
3. Validate the event envelope.
4. Derive stable event identity.
5. Persist or atomically reserve receipt state.
6. Handle duplicates explicitly.
7. Enqueue domain work when request-time processing is inappropriate.
8. Acknowledge according to provider semantics.
9. Test invalid signatures, duplicates, malformed events, retries, and processing failure.

## Example

```ruby
class Webhooks::PaymentsController < ActionController::API
  def create
    payload = request.raw_post
    # 1. Authenticity before parsing into domain objects.
    signature = request.headers["X-Signature"].to_s
    expected = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.credentials.dig(:payments, :webhook_secret), payload)
    return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)

    event = JSON.parse(payload)
    # 2. Durable dedup + fast acknowledgement; processing is asynchronous.
    record = WebhookEvent.create_or_find_by!(provider: "payments", external_id: event.fetch("id")) do |e|
      e.event_type = event.fetch("type")
      e.payload = event
    end
    ProcessWebhookEventJob.perform_later(record) if record.previously_new_record?
    head :ok
  rescue JSON::ParserError, KeyError
    head :bad_request
  end
end
# The job applies events idempotently and tolerates out-of-order delivery via event timestamps.
```

## Failure modes

- parsing before signature verification
- forged event accepted
- duplicate side effects
- event marked processed before durable state
- assuming exactly-once delivery
- relying on arrival order
- slow synchronous processing causing provider retries
- logging secrets/raw signed bodies

## Testing

Test valid/invalid signatures, duplicate delivery, malformed payload, provider retry, and processing failure independently. Use real signature computation with test secrets where practical.

## Review checklist

- [ ] authenticity checked before domain work
- [ ] event identity explicit
- [ ] duplicate semantics explicit
- [ ] durable receipt state where required
- [ ] async boundary deliberate
- [ ] acknowledgement semantics correct
- [ ] ordering assumptions documented
- [ ] secrets protected

## Related skills

- rails-api-integration
- rails-security
- rails-observability
- rails-active-job
- rails-test-engineering
