---
name: active-model-boundary
description: Decide when a Rails-facing plain Ruby object should use Active Model instead of remaining a PORO or becoming Active Record.
family: rails
---

# Active Model Boundary

## Problem

A Ruby object needs some Rails model behavior, but adding Active Record or framework coupling may be unnecessary.

## Use when

- extracting a form/input model;
- integrating a PORO with Rails forms/views;
- deciding between Active Model and Active Record.

## Do not use when

- the object has no Rails model protocol requirement;
- persistence and database lifecycle are intrinsic.

## Repository inspection

Inspect existing POROs, form objects, Active Record models, consumers, routes, views, and tests.

## Implementation procedure

1. Identify the Rails-facing protocol required.
2. Confirm persistence is not intrinsic.
3. Choose the smallest Active Model modules.
4. Keep domain behavior independent where practical.
5. Add lint tests for reusable Rails-facing model contracts.

## Example

```ruby
# Only the Active Model modules the consumer (form_with + validations) needs,
# instead of a table-less Active Record model.
class ContactRequest
  include ActiveModel::API

  attr_accessor :name, :email, :message

  validates :name, :email, :message, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def deliver
    return false unless valid?

    ContactMailer.request(name:, email:, message:).deliver_later
    true
  end
end
```

## Failure modes

- Active Model used as a generic model base;
- persistence concerns leaked into transient objects;
- framework coupling added without a consumer need.

## Testing

Test the actual Rails consumer contract and plain-object behavior separately.

## Review checklist

- [ ] protocol need explicit
- [ ] persistence excluded deliberately
- [ ] smallest modules selected
- [ ] lint/consumer tests exist

## Related skills

- skills/rails-active-model/SKILL.md
- skills/ruby-poro/SKILL.md
- skills/rails-active-record/SKILL.md
