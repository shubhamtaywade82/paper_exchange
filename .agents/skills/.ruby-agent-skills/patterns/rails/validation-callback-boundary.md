---
name: validation-callback-boundary
description: Use when before_validation or after_validation behavior needs an explicit lifecycle boundary.
family: rails
---

# Validation Callback Boundary

## Problem
Validation Callback Boundary needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- deterministic normalization/preparation genuinely belongs to validation lifecycle.

## Do not use when
- callback sends external effects, performs workflow orchestration, or mutates unrelated aggregates.

## Repository inspection
- callback ordering;
- validator definitions;
- related callbacks;
- external effects in nearby code.

## Implementation procedure
1. Prove lifecycle ownership.
2. Keep callback deterministic and local.
3. Establish ordering relative to validators.
4. Keep external work outside callbacks.
5. Test final values observed by validators.

## Example

```ruby
class User < ApplicationRecord
  # Local, deterministic normalization before validation.
  normalizes :email_address, with: ->(email) { email.strip.downcase }
  before_validation :default_display_name, on: :create

  validates :email_address, presence: true, uniqueness: true
  validates :display_name, presence: true

  private

  def default_display_name
    self.display_name = email_address.to_s.split("@").first if display_name.blank?
  end
end
# Not here: sending emails, calling APIs, or checking permissions.
```

## Failure modes
- callback changes validation input unexpectedly;
- after-validation performs external work;
- callback order becomes hidden workflow.

## Testing
- callback/validator ordering;
- repeated validation;
- no external side effects.

## Review checklist
- [ ] ordering is explicit
- [ ] workflow is outside validation
- [ ] deterministic tests exist

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
