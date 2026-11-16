---
name: active-record-testing
description: Use when testing Active Record query, persistence, callback, bulk-operation, and loading contracts.
family: testing
---

# Active Record Testing

## Problem

Model tests often prove only validation or simple persistence while missing Relation shape, lifecycle, callback, bulk-operation, and query-loading contracts.

## Use when

- changing Active Record model behavior
- changing scopes or query objects
- changing callbacks or bulk operations
- changing eager or strict loading.

## Do not use when

- the change is purely schema migration mechanics owned by database engineering.

## Repository inspection

Inspect model test conventions, factories/fixtures, database cleaning/isolation, query assertions, and request/integration consumers.

## Implementation procedure

1. Identify the contract: query, lifecycle, security, or persistence.
2. Test at the narrowest boundary that proves it.
3. Add negative cases for bypassed lifecycle where relevant.
4. Use deterministic data and avoid fragile SQL-string assertions unless SQL shape is the actual contract.
5. Add integration coverage when multiple Rails layers interact.

## Example

```ruby
class InvoiceTest < ActiveSupport::TestCase
  test "reminder_candidates stays a relation and excludes paid invoices" do
    relation = Invoice.reminder_candidates(accounts(:acme))

    assert_kind_of ActiveRecord::Relation, relation
    assert_includes relation, invoices(:overdue_unpaid)
    assert_not_includes relation, invoices(:overdue_paid)
  end

  test "loading candidates runs a bounded number of queries" do
    assert_queries_count(2) do
      Invoice.reminder_candidates(accounts(:acme)).includes(:customer).each { |invoice| invoice.customer.email }
    end
  end

  test "confirmation is enqueued only after commit" do
    assert_no_enqueued_jobs do
      Order.transaction do
        Order.create!(email: "a@example.test")
        raise ActiveRecord::Rollback
      end
    end
  end
end
```

## Failure modes

- asserting only implementation calls
- assuming validation coverage proves query correctness
- tests that depend on row order without an explicit order
- global query counters that create unrelated coupling.

## Testing

Cover as applicable:

- Relation type/composition
- ordering/cardinality
- persistence success/failure
- callback commit/rollback behavior
- bulk-write lifecycle
- deletion/dependent behavior
- strict-loading/N+1 behavior
- tenant/authorization predicates.

## Review checklist

- [ ] actual owning contract is tested
- [ ] failure paths are covered
- [ ] order is explicit
- [ ] tests are deterministic
- [ ] integration behavior is covered where needed

## Related skills

rails-active-record, rails-test-engineering, ruby-tdd-refactoring
