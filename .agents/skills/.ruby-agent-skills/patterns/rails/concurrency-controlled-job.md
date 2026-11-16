---
name: concurrency-controlled-job
description: Bound overlapping background job executions for the same business/resource key.
family: rails
---

# Concurrency Controlled Job

## Problem
Independent workers can execute jobs for the same resource at the same time and violate a business or external-system concurrency contract.

## Use when
Overlap itself is unsafe or a downstream dependency enforces per-resource concurrency limits.

## Do not use when
The real requirement is general worker throughput throttling; prefer queue worker sizing for that case.

## Implementation procedure
1. Identify the shared resource/key.
2. Define the maximum overlap.
3. Choose a stable key.
4. Configure backend-supported concurrency controls.
5. Set an expiry/duration appropriate to the maximum expected execution time.
6. Test overlapping inputs and blocked/released behavior.
7. Verify queue/database capacity.

## Example

```ruby
class SyncAccountJob < ApplicationJob
  # Solid Queue: at most one execution per account at a time; others wait.
  limits_concurrency to: 1, key: ->(account) { account }, duration: 15.minutes

  def perform(account)
    CrmClient.sync(account)
  end
end
```

## Failure modes
- key is too broad and serializes unrelated work
- key is too narrow and permits unsafe overlap
- duration shorter than realistic lock ownership
- concurrency control hides a deeper idempotency problem

## Testing
Exercise two logically conflicting jobs and assert the configured overlap contract.

## Review checklist
- key represents the real resource
- limit is explicit
- duration is justified
- idempotency still exists
- backend support/version is verified

## Related skills
- rails-active-job
- ruby-concurrency
- ruby-performance

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.
