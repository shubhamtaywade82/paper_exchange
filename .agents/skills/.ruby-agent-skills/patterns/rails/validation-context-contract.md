---
name: validation-context-contract
description: Use when introducing or reviewing Rails validation contexts for named operations or state transitions.
family: rails
---

# Validation Context Contract

## Problem
Validation Context Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- create/update rules are insufficient;
- a named operation legitimately requires a distinct validation context.

## Do not use when
- contexts merely hide invalid default states;
- callers cannot identify the owner of the custom context.

## Repository inspection
- valid? callers;
- on and except_on rules;
- workflow/command entry points;
- form/API consumers;
- tests.

## Implementation procedure
1. Name the operation that owns the context.
2. Prefer default/create/update when sufficient.
3. Add the smallest custom context.
4. Make callers explicit.
5. Test shared versus context-only rules.
6. Verify ordinary persistence remains safe.

## Example

```ruby
class Article < ApplicationRecord
  validates :title, presence: true
  # Extra requirements only when explicitly publishing.
  validates :body, :summary, presence: true, on: :publish

  def publish!
    self.published_at = Time.current
    save!(context: :publish) # also runs context-less validations
  end
end

article = Article.create!(title: "Draft") # valid: drafts may be incomplete
article.publish!                           # raises ActiveRecord::RecordInvalid until body/summary exist
```

## Failure modes
- custom contexts proliferate;
- save behavior differs from the context used by the UI;
- context becomes authorization/workflow logic.

## Testing
- default/create/update/custom context;
- omitted context;
- invalid context behavior where relevant.

## Review checklist
- [ ] context has an owner
- [ ] default validation remains safe
- [ ] callers are tested

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
