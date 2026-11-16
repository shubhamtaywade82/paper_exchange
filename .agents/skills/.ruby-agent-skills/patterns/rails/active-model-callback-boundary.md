---
name: active-model-callback-boundary
description: Use explicit Active Model callbacks only for intrinsic model lifecycle hooks and avoid hiding workflows in callback chains.
family: rails
---

# Active Model Callback Boundary

## Problem

Active Model can provide callbacks to plain objects, but callback availability can encourage implicit workflow orchestration.

## Use when

- defining custom model lifecycle events;
- reviewing before/around/after callbacks on a transient model.

## Do not use when

- explicit method/service sequencing is clearer.

## Repository inspection

Inspect callback declarations, lifecycle events, side effects, callers, error handling, and callback tests.

## Implementation procedure

1. Name the lifecycle event.
2. Define callback timing.
3. Keep callbacks narrow and deterministic where possible.
4. Document short-circuit/failure behavior.
5. Prefer explicit services for external side effects.
6. Test callback order and failure semantics.

## Example

```ruby
class Signup
  include ActiveModel::API
  extend ActiveModel::Callbacks

  attr_accessor :email

  define_model_callbacks :normalize

  # Intrinsic, local normalization is a fine callback...
  before_normalize { self.email = email.to_s.strip.downcase }

  def normalize!
    run_callbacks(:normalize) { self }
  end

  # ...but creating accounts and sending mail is an explicit workflow step,
  # not an after_* callback.
  def complete!
    normalize!
    Accounts::Create.call(email: email).tap { |account| WelcomeMailer.welcome(account).deliver_later }
  end
end
```

## Failure modes

- callback chain as hidden workflow;
- network/database calls in lifecycle hooks;
- unclear ordering;
- callbacks added solely for code reuse.

## Testing

Test before/around/after order where present and verify failure stops or continues exactly as intended.

## Review checklist

- [ ] lifecycle event explicit
- [ ] callback ownership justified
- [ ] order documented
- [ ] side effects bounded
- [ ] callback tests exist

## Related skills

- skills/rails-active-model/SKILL.md
- skills/ruby-service-objects/SKILL.md
- skills/ruby-tdd-refactoring/SKILL.md
