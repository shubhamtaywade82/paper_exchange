---
name: active-model-validation-contract
description: Define validation and error semantics for non-persisted Active Model objects.
family: rails
---

# Active Model Validation Contract

## Problem

A transient model can incorrectly become responsible for authorization, persistence integrity, or workflow orchestration merely because it owns validation.

## Use when

- adding Active Model validations;
- changing form/input errors;
- exposing errors to Action View or APIs.

## Do not use when

- the rule is database-only integrity.

## Repository inspection

Inspect input boundary, existing validators, error translations, persisted-model constraints, and consumers.

## Implementation procedure

1. Define the acceptable object state.
2. Add model validation for that state.
3. Keep authorization separate.
4. Keep database invariants with database constraints.
5. Preserve error keys/messages as a contract.
6. Test valid, invalid, boundary, and strict-validation behavior.

## Example

```ruby
class TransferForm
  include ActiveModel::API
  include ActiveModel::Attributes

  attribute :amount_cents, :integer
  attribute :to_account_id, :integer

  # Validation answers "is this input acceptable?" only.
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :to_account_id, presence: true
end

# Authorization and the balance invariant live elsewhere:
form = TransferForm.new(params.expect(transfer: [:amount_cents, :to_account_id]))
if form.valid? && TransferPolicy.new(current_user, form.to_account_id).allowed?
  Transfers::Execute.call(from: current_account, **form.attributes.symbolize_keys) # locks and checks balance
end
```

## Failure modes

- validation used as authorization;
- remote API calls from validators;
- database uniqueness assumed from validation alone;
- error shape changed accidentally.

## Testing

Test valid?, errors, validation contexts, strict failures, and representative input boundaries.

## Review checklist

- [ ] state rule explicit
- [ ] authorization separate
- [ ] persistence integrity separate
- [ ] error contract preserved
- [ ] boundary tests exist

## Related skills

- skills/rails-active-model/SKILL.md
- skills/rails-validations/SKILL.md
- skills/rails-security/SKILL.md
