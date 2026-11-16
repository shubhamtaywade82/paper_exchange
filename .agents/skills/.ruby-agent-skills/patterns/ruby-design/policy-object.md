---
name: policy-object
description: A focused object that answers an authorization or business decision.
family: ruby-design
---

# Policy Object

## Problem

A focused object that answers an authorization or business decision.

## Use when

Use when a decision has multiple conditions, needs reuse, or deserves isolated tests.

## Do not use when

Do not use when a single model predicate is already clear and local.

## Repository inspection

Inspect existing objects that solve the same responsibility, naming and namespace conventions, construction boundaries, tests, and framework-specific conventions before introducing this pattern.

## Implementation procedure

1. Identify the responsibility and public contract.
2. Search the repository for an existing implementation or equivalent abstraction.
3. Define the smallest interface that solves the problem.
4. Keep collaborators explicit and follow local construction conventions.
5. Preserve existing behavior while introducing the boundary.
6. Add focused tests for the contract and important failure cases.
7. Remove duplication only after behavior is covered.
8. Inspect the final diff for unnecessary indirection.

## Example

```ruby
# One decision, no side effects: callers decide what to do with the answer.
class RefundPolicy
  WINDOW = 30 * 24 * 60 * 60

  def initialize(user, order, now: Time.now)
    @user = user
    @order = order
    @now = now
  end

  def allowed?
    return true if @user.admin?

    @order.customer_id == @user.id && @order.paid? && (@now - @order.paid_at) <= WINDOW
  end
end

raise Forbidden unless RefundPolicy.new(current_user, order).allowed?
```

## Failure modes

- applying the pattern because its name sounds sophisticated
- creating an abstraction around trivial code
- hiding dependencies or construction
- adding generic manager/processor classes
- changing behavior during an architectural refactor
- leaking framework or vendor details across the boundary

## Testing

Test the public contract first. Add focused collaborator tests where the pattern creates independently testable behavior. Keep integration tests for real framework or external boundaries.

## Review checklist

- Is the pattern justified by the problem shape?
- Is the interface smaller or clearer than the original coupling?
- Does it match repository conventions?
- Is construction explicit?
- Are failure cases covered?
- Would a simpler implementation be better?

## Related skills

- ruby-poro
- ruby-oop
- ruby-object-composition
- ruby-dependency-injection
- ruby-clean-code
- ruby-tdd-refactoring
