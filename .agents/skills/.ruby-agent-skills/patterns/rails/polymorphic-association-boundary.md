---
name: polymorphic-association-boundary
description: Use when implementing or reviewing polymorphic Active Record associations and their type discriminator.
family: rails
---

# Polymorphic Association Boundary

## Problem

Polymorphic associations store both an identifier and a type, which creates compatibility, security, and lifecycle coupling across multiple model classes.

## Use when

- adding belongs_to polymorphic
- adding has_many through a polymorphic relation
- changing polymorphic type names.

## Do not use when

- the target type set is fixed and a normal foreign key is clearer.

## Repository inspection

Inspect type/id columns, indexes, migrations, allowed target classes, APIs, serializers, and authorization.

## Implementation procedure

1. Define the finite set of supported target classes.
2. Keep type values out of untrusted direct constantization.
3. Index the discriminator/id combination as appropriate.
4. Define deletion and authorization semantics per target class.
5. Plan class-renaming or migration compatibility.

## Example

```ruby
class Comment < ApplicationRecord
  COMMENTABLE_TYPES = %w[Post Photo].freeze

  belongs_to :commentable, polymorphic: true
  validates :commentable_type, inclusion: { in: COMMENTABLE_TYPES }
end

class CommentsController < ApplicationController
  def create
    type = params.require(:commentable_type)
    # Never constantize client input directly.
    klass = { "Post" => Post, "Photo" => Photo }.fetch(type) { return head(:unprocessable_entity) }
    commentable = klass.where(account: Current.account).find(params.require(:commentable_id))
    commentable.comments.create!(body: params.require(:body), author: Current.user)
    head :created
  end
end
# DB: index on [commentable_type, commentable_id]; a CHECK constraint mirrors COMMENTABLE_TYPES.
```

## Failure modes

- arbitrary type constantization
- client-controlled class names
- missing type/id indexing
- inconsistent authorization across target classes.

## Testing

Test each allowed type, unsupported type, cross-tenant target, deletion, and serialization path.

## Review checklist

- [ ] allowed types are explicit
- [ ] type input is bounded
- [ ] indexes are appropriate
- [ ] authorization is target-aware
- [ ] rename/migration behavior is known

## Related skills

rails-associations, rails-security, rails-database-engineering, rails-zeitwerk
