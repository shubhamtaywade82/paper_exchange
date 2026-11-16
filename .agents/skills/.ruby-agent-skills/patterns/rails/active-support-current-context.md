---
name: active-support-current-context
description: Define narrow CurrentAttributes usage with explicit reset, ownership, concurrency, and background-job boundaries.
family: rails
---

# Active Support Current Context

## Problem

CurrentAttributes reduces parameter plumbing but creates implicit request/execution context that can leak or become an unofficial global variable.

## Use when

- adding CurrentAttributes;
- storing current user/request/tenant context;
- debugging context leakage between requests/jobs.

## Do not use when

- explicit dependency passing is practical and clearer;
- state must survive as durable business data.

## Repository inspection

Inspect Current class, middleware/controller setters, reset hooks, jobs, threads/fibers, request tests, and existing context conventions.

## Implementation procedure

1. Define the minimal context contract.
2. Identify the writer and owner for every attribute.
3. Define reset semantics.
4. Propagate durable context explicitly into jobs/events.
5. Avoid storing mutable domain state or caches.
6. Add isolation tests.

## Example

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :request_id
end

class ApplicationController < ActionController::Base
  before_action do
    Current.user = current_user
    Current.account = current_user&.account
    Current.request_id = request.request_id
  end
end

# Current is reset per request and job execution, and is NOT carried into
# jobs: pass what the job needs explicitly and re-load it there.
AuditJob.perform_later(account_id: Current.account.id, actor_id: Current.user.id, request_id: Current.request_id)
```

## Failure modes

- context leaks across requests/tests;
- job assumes request context exists;
- CurrentAttributes becomes a global business-state store;
- tenant/user context is missing at a privileged boundary.

## Testing

Test set/reset behavior, nested operations, request isolation, job handoff, and concurrent execution boundaries where applicable.

## Review checklist

- [ ] attributes minimal
- [ ] writers explicit
- [ ] reset guaranteed
- [ ] job propagation explicit
- [ ] no durable business state
- [ ] isolation tested

## Related skills

- skills/rails-active-support/SKILL.md
- skills/ruby-concurrency/SKILL.md
- skills/rails-active-job/SKILL.md
- skills/rails-security-engineering/SKILL.md
