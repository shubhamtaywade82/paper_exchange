---
name: command-object
description: A focused object representing one executable application action.
family: ruby-design
---

# Command Object

## Problem

A focused object representing one executable application action.

## Use when

Use when an operation has explicit inputs, an execution boundary, and a result or failure contract.

## Do not use when

Do not use when a simple method already expresses the operation clearly.

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
# One executable action with one public method and an explicit result.
class Invoices::Void
  Result = Data.define(:invoice, :error)

  def initialize(invoice, reason:)
    @invoice = invoice
    @reason = reason
  end

  def call
    return Result.new(invoice: @invoice, error: :already_paid) if @invoice.paid?

    @invoice.update!(voided_at: Time.current, void_reason: @reason)
    Result.new(invoice: @invoice, error: nil)
  end
end

result = Invoices::Void.new(invoice, reason: "duplicate").call
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
