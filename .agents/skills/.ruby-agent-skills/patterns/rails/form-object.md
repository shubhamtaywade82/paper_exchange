---
name: form-object
description: Use when input validation and transformation span multiple models or represent a user/application form rather than one persistence record.
family: rails
---

# Form Object

## Problem

A request/form has validation and input-shaping rules that do not naturally belong to one Active Record model.

## Use when

- one form writes multiple models
- input is transient and not itself a persisted record
- validation differs from persistence-model validation
- controller parameter handling is becoming domain-heavy

## Do not use when

- a normal model validation already expresses the contract
- the object only renames one parameter

## Repository inspection

Inspect form/presenter objects, request validation, model validations, error serialization, and controller conventions.

## Structure

~~~ruby
class RegistrationForm
  include ActiveModel::Model

  attr_accessor :email, :password

  validates :email, presence: true
  validates :password, presence: true

  def save
    return false unless valid?

    User.create!(email: email, password: password)
  end
end
~~~

The persistence and transaction semantics must follow the actual application requirements.

## Implementation procedure

1. Identify the input-level contract.
2. Separate input validation from persistence invariants.
3. Define fields and errors.
4. Coordinate writes explicitly.
5. Define transaction/failure behavior.
6. Keep controller orchestration small.
7. Test valid, invalid, and partial-failure cases.

## Failure modes

- duplicate model validations without a reason
- hidden multi-record transaction behavior
- form object becoming a general service
- leaking raw request params into persistence

## Testing

Test the form contract independently and integration-test the resulting request workflow when multiple Rails layers interact.

## Review checklist

- [ ] form has a distinct input contract
- [ ] persistence rules remain with models/database
- [ ] transaction behavior is explicit
- [ ] errors are compatible with the UI/API
- [ ] controller remains focused

## Related skills

- rails-action-controller
- rails-validations
- rails-active-record
- rails-test-engineering
- ruby-method-design
