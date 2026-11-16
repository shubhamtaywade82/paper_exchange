---
name: repository
description: An abstraction around persistence access when the repository boundary has independent domain value.
family: ruby-design
---

# Repository

## Problem

An abstraction around persistence access when the repository boundary has independent domain value.

## Use when

Use when persistence access is complex, multiple stores exist, or domain code genuinely benefits from a stable persistence contract.

## Do not use when

Do not use as a generic wrapper around every Active Record query.

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
# Earns its boundary: persistence spans two stores and the domain should not
# know which record lives where.
class CustomerRepository
  def initialize(records: Customer, archive: ArchiveClient.new)
    @records = records
    @archive = archive
  end

  def find(id)
    @records.find_by(id: id) || @archive.fetch_customer(id)
  end

  def save(customer)
    customer.archived? ? @archive.store_customer(customer) : customer.save!
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
