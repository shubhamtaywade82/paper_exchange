---
name: active-support-concern-composition
description: Design narrow ActiveSupport::Concern modules with explicit host contracts and dependency-safe composition.
family: rails
---

# Active Support Concern Composition

## Problem

Concerns can reduce duplication but can also create invisible inheritance, callback, and dependency graphs.

## Use when

- adding/refactoring a concern;
- sharing behavior across controllers/models/services;
- reviewing concern dependencies.

## Do not use when

- an explicit collaborator/object is clearer.

## Repository inspection

Inspect existing concerns, host classes, callbacks, class methods, dependency chains, and tests.

## Implementation procedure

1. Name the cohesive capability.
2. Define the host contract.
3. Declare dependencies explicitly.
4. Keep included/prepended blocks small.
5. Keep class_methods focused.
6. Avoid unrelated callbacks or persistence queries.
7. Test inclusion order and host behavior.

## Example

```ruby
# One cohesive capability with a documented host contract.
module Archivable
  extend ActiveSupport::Concern

  # Host contract: an `archived_at` datetime column.
  included do
    scope :archived, -> { where.not(archived_at: nil) }
    scope :kept, -> { where(archived_at: nil) }
  end

  def archive!(at: Time.current) = update!(archived_at: at)
  def archived? = archived_at.present?
end

class Project < ApplicationRecord
  include Archivable
end
```

## Failure modes

- god concern;
- circular/hidden dependency;
- callback injection surprises;
- concern assumes methods the host does not expose;
- concern changes public API broadly.

## Testing

Test the concern with representative hosts and dependency combinations.

## Review checklist

- [ ] host contract explicit
- [ ] dependencies explicit
- [ ] lifecycle effects bounded
- [ ] class/instance APIs intentional
- [ ] representative hosts tested

## Related skills

- skills/rails-active-support/SKILL.md
- skills/ruby-object-composition/SKILL.md
- skills/ruby-modules-mixins/SKILL.md
