---
name: active-record-scope-contract
description: Use when adding or reviewing named scopes or default_scope behavior.
family: rails
---

# Active Record Scope Contract

## Problem

Scopes can hide filters, ordering, joins, defaults, and expensive behavior that callers assume are neutral.

## Use when

- adding a scope
- changing default_scope
- replacing repeated where clauses
- reviewing unscoped behavior.

## Do not use when

- the behavior is a one-off query with no reusable semantic name.

## Repository inspection

Inspect existing scopes, default_scope, unscoped callers, creation paths, and authorization/tenant conventions.

## Implementation procedure

1. Give the scope a semantic, domain-relevant name.
2. Keep it relation-valued and side-effect free.
3. Document ordering/joins if they affect composition.
4. Prefer explicit scopes over broad default_scope for visibility rules.
5. Test both scoped and deliberately unscoped paths.

## Example

```ruby
class Post < ApplicationRecord
  # Named, narrow, unsurprising: a filter only, no ordering or joins hidden
  # inside, so callers choose those explicitly.
  scope :published, -> { where.not(published_at: nil) }
  scope :by_author, ->(author) { where(author: author) }

  # Avoid: default_scope { where(deleted_at: nil) } as a security filter, or
  # scopes that return an Array or call external services.
end

Post.published.by_author(user).order(published_at: :desc)
Post.unscope(where: :published_at) # nothing implicit to fight against
```

## Failure modes

- default_scope as authorization
- scope with external I/O
- surprising ordering or limiting
- creation semantics changed unintentionally by default_scope.

## Testing

Assert chained scope behavior, unscoped behavior, and creation defaults where applicable.

## Review checklist

- [ ] semantics are explicit
- [ ] scope is composable
- [ ] security does not depend on hidden scope
- [ ] default_scope impact was audited

## Related skills

rails-active-record, rails-security, rails-database-engineering
