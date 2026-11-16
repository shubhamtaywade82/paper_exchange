---
name: application-service
description: A shared entry-point convention for application operations.
family: ruby-design
---

# Application Service

## Problem

A shared entry-point convention for application operations.

## Use when

Use when multiple services consistently expose the same class-level entry point and the repository benefits from a small common convention.

## Do not use when

Do not use when the repository has no service convention or the base class would add no meaningful behavior.

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
# One entry-point convention shared by application operations.
class ApplicationService
  def self.call(...)
    new(...).call
  end
end

class Accounts::Close < ApplicationService
  def initialize(account, closed_by:)
    @account = account
    @closed_by = closed_by
  end

  def call
    @account.update!(closed_at: Time.current, closed_by: @closed_by)
    @account
  end
end

Accounts::Close.call(account, closed_by: current_user)
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
