---
name: contextual-authorization
description: Apply authorization rules that depend on explicit resource state, tenant, ownership, or other context.
family: rails
---
# Contextual Authorization

## Problem
Permission depends on more than actor and resource identity.

## Use when
State, ownership, tenant membership, time, delegation, or other explicit context changes the decision.

## Structure
Make relevant context explicit and deterministic.

## Example

```ruby
# The decision depends on explicit context: time of day, the request's
# network zone, and the record's state — all passed in, nothing ambient.
class PayrollPolicy
  def initialize(user, run, now:, network:)
    @user = user
    @run = run
    @now = now
    @network = network
  end

  def approve?
    @user.payroll_approver? &&
      @run.status == "pending_approval" &&
      @network == :corporate &&
      @now.on_weekday?
  end
end

PayrollPolicy.new(current_user, run, now: Time.current, network: request_network_zone).approve?
```

## Implementation procedure
Identify authoritative context, pass it to the decision boundary, and test combinations that change the outcome.

## Failure modes
Hidden global context, client-controlled context, and inconsistent state reads.

## Testing
Cover each context dimension and important intersections.

## Review checklist
Every authorization input is explicit and authoritative.

## Do not use when

Do not introduce this pattern when direct repository policy or scope logic is clearer and complete.

## Repository inspection

Inspect the existing authorization mechanism, callers, resource ownership, tenant scope, tests, and resolved framework versions.

## Related skills

rails-authorization, rails-security, rails-active-record, rails-test-engineering
