---
name: active-model-testing
description: Test Active Model protocol behavior, validations, attributes, callbacks, conversion, and Rails consumers deterministically.
family: rails
---

# Active Model Testing

## Problem

Plain model-like objects can pass isolated tests while failing when consumed by forms, views, routes, or Rails model protocols.

## Use when

- adding Active Model objects;
- changing model protocol behavior;
- fixing form/view integration;
- reviewing reusable form/model abstractions.

## Do not use when

- the object has no Rails-facing model contract.

## Repository inspection

Inspect test framework, existing Active Model lint tests, form/view/request tests, fixtures, and integration conventions.

## Implementation procedure

1. Unit-test intrinsic object behavior.
2. Run Active Model lint tests for the model protocol where applicable.
3. Test Rails consumers at the smallest integration boundary.
4. Cover attributes, validations, conversion, callbacks, serialization, and translation as used.
5. Add security negatives for sensitive serialization or URL semantics.

## Example

```ruby
class ContactRequestTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  # The lint tests prove the object works with form_with, url_for, and errors.
  setup { @model = ContactRequest.new }

  test "invalid without an email" do
    request = ContactRequest.new(name: "Sam", message: "Hi")
    refute request.valid?
    assert_equal [:blank], request.errors.details[:email].map { |d| d[:error] }
  end
end

class ContactRequestsFormTest < ActionDispatch::IntegrationTest
  test "form renders and re-renders with errors" do
    post contact_requests_path, params: { contact_request: { name: "Sam" } }
    assert_response :unprocessable_content
    assert_select "form[action=?]", contact_requests_path
  end
end
```

## Failure modes

- only happy-path unit tests;
- no lint coverage;
- tests asserting implementation details;
- Rails integration failures discovered late.

## Testing

Use deterministic unit tests plus focused form/view/request tests.

## Review checklist

- [ ] intrinsic behavior tested
- [ ] lint contract tested
- [ ] actual Rails consumers tested
- [ ] used modules have coverage
- [ ] security cases covered where relevant

## Related skills

- skills/rails-active-model/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md
