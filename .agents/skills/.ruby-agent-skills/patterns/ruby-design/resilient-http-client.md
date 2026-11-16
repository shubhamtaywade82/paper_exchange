---
name: resilient-http-client
description: Design a bounded, testable outbound HTTP client with explicit timeout, retry, error, and idempotency semantics.
family: ruby-design
---

# Resilient HTTP Client

## Problem

A provider integration needs reliability without creating unbounded latency or duplicate side effects.

## Use when

Designing or reviewing an external HTTP client with timeouts, retries, throttling, or ambiguous mutation outcomes.

## Do not use when

The integration is a trivial request with no meaningful retry/resilience requirement.

## Repository inspection

Inspect HTTP library, Ruby/runtime versions, provider contract, timeout settings, retry conventions, rate limits, authentication, idempotency support, and existing test doubles.

## Implementation procedure

1. Define a narrow transport abstraction.
2. Configure bounded connect/read/request deadlines.
3. Classify retryable versus permanent failures.
4. Apply a finite retry budget with bounded backoff/jitter.
5. Avoid retrying unsafe mutations unless idempotency is guaranteed.
6. Map provider failures to stable application errors.
7. Propagate safe correlation metadata.
8. Test success, timeout, transient failure, retry exhaustion, and malformed responses.
9. Measure latency/retry behavior before claiming reliability gains.

## Example

```ruby
require "net/http"

# Bounded timeouts, bounded retries, and retries only for idempotent requests
# or those carrying an idempotency key.
class ResilientClient
  RETRYABLE = [Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET].freeze
  MAX_ATTEMPTS = 3

  def initialize(http:, sleeper: ->(seconds) { sleep(seconds) })
    @http = http
    @sleeper = sleeper
  end

  def post_payment(payload, idempotency_key:)
    with_retries do
      @http.post("/payments", payload, "Idempotency-Key" => idempotency_key)
    end
  end

  private

  def with_retries
    attempt = 0
    begin
      attempt += 1
      yield
    rescue *RETRYABLE
      raise if attempt >= MAX_ATTEMPTS

      @sleeper.call(0.2 * (2**attempt))
      retry
    end
  end
end
```

## Failure modes

- retry storms
- unbounded retries
- retrying authentication/validation errors
- duplicate non-idempotent mutations
- missing timeouts
- hiding the provider failure
- logging credentials or sensitive payloads

## Testing

Use a fake transport. Test timeout, transient failure, exhaustion, non-retryable status, malformed body, and mutation/idempotency behavior separately.

## Review checklist

- [ ] timeout bounds explicit
- [ ] retry classification explicit
- [ ] retry budget finite
- [ ] backoff bounded
- [ ] mutation idempotency understood
- [ ] provider errors mapped
- [ ] secrets protected
- [ ] failure paths tested

## Related skills

- rails-api-integration
- ruby-gems-io-services
- ruby-dependency-injection
- ruby-concurrency
- ruby-performance
