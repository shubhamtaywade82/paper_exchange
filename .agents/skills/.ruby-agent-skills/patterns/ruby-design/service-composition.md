---
name: service-composition
description: A composition boundary for a workflow that coordinates multiple focused operations.
family: ruby-design
---

# Service Composition

## Problem

A composition boundary for a workflow that coordinates multiple focused operations.

## Use when

Use when a workflow legitimately requires several independent operations and orchestration belongs in one application action.

## Do not use when

Do not use to create deep chains of services that merely forward calls.

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
# Coordinates focused operations; each step stays independently testable.
class Signup
  def initialize(create_account: Accounts::Create, send_welcome: Notifications::Welcome, track: Analytics::Track)
    @create_account = create_account
    @send_welcome = send_welcome
    @track = track
  end

  def call(params)
    account = ActiveRecord::Base.transaction { @create_account.call(params) }
    @send_welcome.call(account)
    @track.call("signup", account_id: account.id)
    account
  end
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
