---
name: query-object
description: Use when a database query has meaningful business intent, joins/filters become complex, or query logic needs independent testing without bloating a model.
family: rails
---

# Query Object

## Problem

A query has enough business meaning or complexity that embedding it in a model, controller, or service obscures its purpose.

## Use when

- multiple joins/conditions express a domain query
- a query is reused
- query performance needs focused testing/inspection
- a model's scopes are becoming a large query API

## Do not use when

- a simple scope or relation is already clear
- the query is used once and is easier to read inline

## Repository inspection

Inspect existing scopes/query objects, database indexes, schema, generated SQL, and test conventions.

## Structure

~~~ruby
class AvailableOrders
  def initialize(scope = Order.all)
    @scope = scope
  end

  def call
    @scope
      .where(status: "pending")
      .where("expires_at > ?", Time.current)
  end
end
~~~

Use repository-specific query composition and time helpers.

## Implementation procedure

1. Name the query after the business question.
2. Define its input relation and output relation.
3. Keep it read-oriented.
4. Inspect SQL and index support for important queries.
5. Test result correctness and important performance constraints.
6. Avoid putting mutation into a query object.

## Failure modes

- query object that only wraps Model.where
- hidden writes
- unbounded result loading
- missing indexes for important filters
- business mutation mixed into querying

## Testing

Test representative data, empty results, boundary conditions, joins, ordering, and query count/performance where materially important.

## Review checklist

- [ ] query has meaningful domain intent
- [ ] relation contract is clear
- [ ] SQL/index behavior considered
- [ ] no side effects
- [ ] tests cover important cases

## Related skills

- rails-active-record
- rails-associations
- rails-test-engineering
- ruby-clean-code
