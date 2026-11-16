---
name: job-retry-policy
description: Define explicit Active Job retry/discard behavior for transient and permanent failures.
family: rails
---

# Job Retry Policy

## Problem
Unbounded, immediate, or semantically incorrect retries can amplify incidents or repeat permanent failures.

## Use when
A job talks to unreliable infrastructure, rate-limited dependencies, or has explicit transient/permanent exception classes.

## Do not use when
The work is deterministic and failures should immediately surface without retry.

## Implementation procedure
1. Classify exceptions as transient or permanent.
2. Use retry_on only for transient failures.
3. Choose attempts and backoff from recovery/capacity expectations.
4. Add jitter when synchroni
zed retry bursts are possible.
5. Use discard_on only when retrying is not meaningful.
6. Report terminal failures when operational action is required.
7. Test each exception path.

## Example

```ruby
class DeliverWebhookJob < ApplicationJob
  # Transient: bounded, backed off, jittered.
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET,
           wait: :polynomially_longer, attempts: 8
  retry_on Webhooks::ServerError, wait: :polynomially_longer, attempts: 8 # 5xx/429

  # Permanent: retrying cannot succeed.
  discard_on Webhooks::ClientError do |job, error| # 4xx except 429
    Webhooks::Delivery.find(job.arguments.first).update!(status: :failed, last_error: error.message)
  end

  def perform(delivery_id)
    Webhooks::Delivery.find(delivery_id).deliver!
  end
end
```

## Failure modes
- retrying authorization/validation failures
- infinite rapid retries
- catching broad exceptions and retrying everything
- retrying a non-idempotent side effect without protection

## Testing
Assert retry scheduling/attempt policy and terminal discard/failure behavior.

## Review checklist
- exception taxonomy is explicit
- backoff is justified
- attempts are bounded unless unlimited is intentional
- terminal failures remain observable

## Related skills
- rails-active-job
- ruby-debugging
- ruby-performance

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.
