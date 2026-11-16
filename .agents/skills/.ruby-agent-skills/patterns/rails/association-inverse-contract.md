---
name: association-inverse-contract
description: Use when association identity, autosave, validation, or query behavior depends on a bidirectional inverse relationship.
family: rails
---

# Association Inverse Contract

## Problem

Rails may infer inverse associations in common cases, but custom foreign keys, class names, scopes, and through relationships can prevent automatic recognition.

## Use when

- adding inverse_of
- changing foreign_key or class_name
- debugging duplicate queries or unexpected autosave/validation behavior.

## Do not use when

- the association is intentionally one-directional.

## Repository inspection

Inspect both declarations, foreign keys, scopes, class names, through relationships, and consumers.

## Implementation procedure

1. Establish the intended bidirectional relationship.
2. Verify automatic inference for the resolved Rails version.
3. Add inverse_of explicitly where inference is not reliable.
4. Test object identity, validation, and autosave behavior.
5. Recheck query behavior for representative traversals.

## Example

```ruby
class Author < ApplicationRecord
  # Custom foreign key: Rails cannot infer the inverse, so state it.
  has_many :books, foreign_key: :writer_id, inverse_of: :writer
end

class Book < ApplicationRecord
  belongs_to :writer, class_name: "Author", inverse_of: :books
end

author = Author.includes(:books).first
author.books.first.writer.equal?(author) # => true: same object, no extra query
```

## Failure modes

- assuming every association is automatically inverse
- declaring an incorrect inverse
- adding inverse_of without testing the consumer behavior.

## Testing

Exercise parent-to-child-to-parent traversal, building through the inverse, validation, and save behavior.

## Review checklist

- [ ] both directions are correct
- [ ] inference assumptions are explicit
- [ ] inverse identity is tested
- [ ] autosave/validation behavior is understood

## Related skills

rails-associations, rails-active-record, rails-validations
