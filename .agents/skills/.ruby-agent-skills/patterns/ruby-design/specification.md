---
name: specification
description: A composable object representing a business predicate.
family: ruby-design
---

# Specification

## Problem

A composable object representing a business predicate.

## Use when

Use when predicates are complex, reusable, or need composition and isolated tests.

## Do not use when

Do not use for a single readable boolean expression.

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
# Named, composable predicates reused by queries and in-memory checks.
class Specification
  def and(other) = AndSpecification.new(self, other)
end

class AndSpecification < Specification
  def initialize(left, right)
    @left = left
    @right = right
  end

  def satisfied_by?(candidate) = @left.satisfied_by?(candidate) && @right.satisfied_by?(candidate)
end

class ActiveSubscriber < Specification
  def satisfied_by?(user) = user.subscription&.active?
end

class EngagedLastMonth < Specification
  def satisfied_by?(user) = user.last_seen_at && user.last_seen_at > 30.days.ago
end

eligible = ActiveSubscriber.new.and(EngagedLastMonth.new)
users.select { |user| eligible.satisfied_by?(user) }
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
