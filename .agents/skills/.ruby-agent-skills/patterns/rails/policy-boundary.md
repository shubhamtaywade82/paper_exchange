---
name: policy-boundary
description: Use when authorization rules need a dedicated, testable boundary rather than being scattered through controllers or views.
family: rails
---

# Policy Boundary

## Problem

Authorization rules are becoming duplicated or mixed with request/presentation logic.

## Use when

- the repository already uses policy objects
- authorization decisions have meaningful domain rules
- the same permission is checked from multiple entry points

## Do not use when

- the application already has a stable authorization abstraction that should be reused
- the rule is a single obvious ownership check and a new abstraction would add indirection

## Repository inspection

Inspect the existing authorization library, policy naming, controller hooks, scopes, and tests.

## Structure

~~~ruby
class OrderPolicy
  def initialize(user, order)
    @user = user
    @order = order
  end

  def update?
    @order.user_id == @user.id && @order.editable?
  end
end
~~~

Use the repository's actual policy framework and conventions.

## Implementation procedure

1. Identify the protected operation.
2. Identify the subject and requester.
3. Separate authentication from authorization.
4. Define the smallest permission interface.
5. Reuse the policy at every required server-side entry point.
6. Test allowed and denied cases.

## Failure modes

- authorization only in the UI
- duplicated permission rules
- policy objects performing mutations
- leaking sensitive resource existence through error behavior
- bypassing the policy from background jobs or alternate entry points

## Testing

Test permissions by role/ownership/state and exercise important HTTP boundaries.

## Review checklist

- [ ] server-side enforcement exists
- [ ] authentication and authorization remain distinct
- [ ] policy has one coherent responsibility
- [ ] alternate entry points considered
- [ ] denied behavior tested

## Related skills

- rails-authentication
- rails-action-controller
- rails-test-engineering
- rails-active-record
