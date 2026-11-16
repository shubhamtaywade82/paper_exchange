---
name: dependency-injection
description: An explicit composition boundary for replaceable collaborators.
family: ruby-design
---

# Dependency Injection

## Problem

An explicit composition boundary for replaceable collaborators.

## Use when

Use when external or variable collaborators need isolation, substitution, or a narrow interface.

## Do not use when

Do not use a container framework merely to pass ordinary Ruby objects.

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
# Collaborators are passed in, with production defaults; tests pass fakes.
class OverdueReminder
  def initialize(clock: Time, mailer: ReminderMailer)
    @clock = clock
    @mailer = mailer
  end

  def call(invoice)
    return false unless invoice.due_on < @clock.now.to_date

    @mailer.overdue(invoice).deliver_later
    true
  end
end

# In a test:
FrozenClock = Struct.new(:now)
reminder = OverdueReminder.new(clock: FrozenClock.new(Time.utc(2026, 1, 31)), mailer: FakeMailer.new)
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
