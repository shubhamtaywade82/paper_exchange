---
name: active-model-dirty-lifecycle
description: Define explicit dirty-state transitions for non-persisted Active Model objects.
family: rails
---

# Active Model Dirty Lifecycle

## Problem

Dirty tracking on plain objects has no automatic persistence lifecycle; stale change information can easily be misinterpreted.

## Use when

- adding ActiveModel::Dirty;
- implementing commit/reset/rollback behavior on transient objects.

## Do not use when

- no caller needs change tracking.

## Repository inspection

Inspect setters, mutation methods, persistence/writer workflow, reset behavior, and tests.

## Implementation procedure

1. Declare tracked attributes.
2. Mark changes at mutation points.
3. Define what apply, reset, and rollback mean.
4. Call the appropriate Dirty lifecycle methods.
5. Keep irreversible side effects outside mere assignment.
6. Test current and previous values.

## Example

```ruby
class Preferences
  include ActiveModel::Dirty

  define_attribute_methods :theme

  def theme = @theme

  def theme=(value)
    theme_will_change! unless value == @theme
    @theme = value
  end

  # Change tracking only means something relative to an explicit save/reset.
  def save
    return true unless changed?

    PreferenceStore.write(theme: @theme)
    changes_applied
    true
  end

  def discard = restore_attributes
end
```

## Failure modes

- Dirty state treated as persistence;
- missing change marking;
- stale previous changes;
- side effects triggered during setters.

## Testing

Test assignment, repeated assignment, apply, reset, rollback, and previous/current values.

## Review checklist

- [ ] tracked fields explicit
- [ ] mutation hooks explicit
- [ ] apply/reset semantics explicit
- [ ] side effects not hidden in assignment
- [ ] lifecycle tests exist

## Related skills

- skills/rails-active-model/SKILL.md
- skills/rails-active-record/SKILL.md
