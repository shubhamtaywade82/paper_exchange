---
name: request-error-boundary
description: Map Rails/domain exceptions to stable HTTP responses at the correct request boundary.
family: rails
---

# Request Error Boundary

## Problem
Internal exceptions need a stable HTTP contract without leaking implementation details.

## Use when
A Rails API/controller needs explicit mapping for validation, authorization, not-found, conflict, domain, or unexpected failures.

## Implementation procedure
1. Inspect existing error response conventions.
2. Identify exception ownership.
3. Map expected client errors to stable status/body contracts.
4. Keep unexpected failures on the standard 5xx/reporting path.
5. Avoid duplicating formatting across controllers.
6. Test success, known failure, and unexpected failure paths.

## Example

```ruby
class Api::BaseController < ActionController::API
  # Only expected, classified errors get a mapping; everything else stays a 500
  # handled (and reported) by Rails.
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: { code: "not_found" } }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: { code: "invalid_request", param: e.param } }, status: :bad_request
  end

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: { code: "not_found" } }, status: :not_found # no existence disclosure
  end
end
```

## Failure modes
- rescue StandardError and return 200
- expose exception messages/backtraces
- map infrastructure failures to 4xx
- duplicate JSON error shapes

## Testing
Assert status, content type, stable error fields, and no sensitive exception detail.

## Review checklist
- exception mapping is narrow
- status semantics are correct
- unexpected failures remain observable
- error body is stable

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.

## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when the concern is entirely internal and has no HTTP exception-to-response contract.
