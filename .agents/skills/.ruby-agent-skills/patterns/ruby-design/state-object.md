---
name: state-object
description: An object that encapsulates behavior that changes according to an entity's current state.
family: ruby-design
---

# State Object

## Problem

An object that encapsulates behavior that changes according to an entity's current state.

## Use when

Use when state-specific branching is repeated and each state has meaningful behavior.

## Do not use when

Do not use for a small conditional with only one or two branches.

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
# Behaviour that depends on state lives in the state objects, not in case
# statements scattered across the entity.
class Order
  attr_reader :state

  def initialize
    @state = Pending.new
  end

  def pay! = @state = @state.pay
  def ship! = @state = @state.ship

  class Pending
    def pay = Paid.new
    def ship = raise(InvalidTransition, "cannot ship an unpaid order")
  end

  class Paid
    def pay = raise(InvalidTransition, "already paid")
    def ship = Shipped.new
  end

  class Shipped
    def pay = raise(InvalidTransition, "already paid")
    def ship = raise(InvalidTransition, "already shipped")
  end

  InvalidTransition = Class.new(StandardError)
end
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
