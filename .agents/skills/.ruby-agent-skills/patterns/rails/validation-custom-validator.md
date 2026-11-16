---
name: validation-custom-validator
description: Use when a coherent Rails validation rule is genuinely reusable across model types.
family: rails
---

# Custom Validator Contract

## Problem
Custom Validator Contract needs an explicit contract so validation does not drift between model logic, database integrity, and consumers.

## Use when
- one coherent validation rule is reused across model types;
- configuration is part of the reusable contract.

## Do not use when
- the rule is one simple local predicate;
- validator performs I/O or persistence.

## Repository inspection
- existing validators;
- domain vocabulary;
- options;
- error types/translations;
- consumers.

## Implementation procedure
1. Confirm real reuse.
2. Choose ActiveModel::Validator or ActiveModel::EachValidator.
3. Keep execution deterministic and side-effect free.
4. Define stable error types/options.
5. Test every consuming model.

## Example

```ruby
# app/validators/gstin_validator.rb — reused by Customer and Supplier.
class GstinValidator < ActiveModel::EachValidator
  FORMAT = /\A\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/

  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_blank]
    record.errors.add(attribute, :invalid_gstin) unless value.to_s.match?(FORMAT)
  end
end

class Customer < ApplicationRecord
  validates :gstin, gstin: { allow_blank: true }
end
# config/locales/en.yml: en.activerecord.errors.messages.invalid_gstin: "is not a valid GSTIN"
```

## Failure modes
- validator exists only for indirection;
- external calls during validation;
- hidden mutable state.

## Testing
- each consumer;
- option combinations;
- valid/invalid;
- repeated execution.

## Review checklist
- [ ] reuse justifies abstraction
- [ ] no side effects
- [ ] options are explicit

## Related skills
- rails-validations
- rails-active-record
- rails-database-engineering
- rails-test-engineering
