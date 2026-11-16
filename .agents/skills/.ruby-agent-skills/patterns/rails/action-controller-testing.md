---
name: action-controller-testing
description: Use when testing an Action Controller HTTP contract across request input, response behavior, lifecycle, and error paths.
family: testing
---

# Action Controller Testing

## Problem

Controller changes are easy to test only through happy paths while missing input, format, lifecycle, state, redirect, and error semantics.

## Use when

- changing controller behavior
- adding a response format
- changing parameters/session/cookies
- adding callbacks or exception mappings
- implementing downloads or conditional responses.

## Do not use when

- no observable controller behavior changes.

## Repository inspection

Inspect request/integration/system test conventions, helper setup, authentication helpers, shared contexts, and supported test APIs.

## Implementation procedure

1. Identify the externally observable HTTP contract.
2. Select the narrowest request-level test boundary that proves it.
3. Add negative cases before broad integration coverage where practical.
4. Keep external providers/storage local or stubbed at their actual boundary.
5. Assert status/format/headers/body or redirect explicitly where contractual.
6. Add regression coverage for security-sensitive boundary changes.

## Example

```ruby
class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:owner) }

  test "json response contract" do
    get report_path(reports(:q3)), as: :json
    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal %w[id name], response.parsed_body.keys.sort
  end

  test "unsupported format is rejected" do
    get report_path(reports(:q3), format: :xml)
    assert_response :not_acceptable
  end

  test "conditional GET returns 304" do
    get report_path(reports(:q3)), as: :json
    get report_path(reports(:q3)), as: :json, headers: { "If-None-Match" => response.headers["ETag"] }
    assert_response :not_modified
  end

  test "missing root key is a 400" do
    patch report_path(reports(:q3)), params: { name: "x" }, as: :json
    assert_response :bad_request
  end
end
```

## Failure modes

- asserting only internal method calls
- testing callback implementation instead of observable behavior
- live network/storage services in ordinary CI
- omitting unauthorized/invalid-format cases.

## Testing

Cover as applicable:

- valid/invalid parameters
- authentication/authorization
- response status and representation
- redirect behavior
- sessions/cookies/flash
- callback-scoped actions
- conditional 304 responses
- expected exceptions
- download/stream headers and failures.

## Review checklist

- [ ] test proves HTTP behavior
- [ ] failure cases are included
- [ ] security boundaries are covered
- [ ] tests are deterministic
- [ ] assertions match supported Rails test APIs

## Related skills

rails-action-controller, rails-test-engineering, ruby-tdd-refactoring
