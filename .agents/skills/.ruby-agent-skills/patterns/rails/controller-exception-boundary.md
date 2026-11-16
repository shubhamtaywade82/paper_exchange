---
name: controller-exception-boundary
description: Use when controller exceptions must be mapped to stable HTTP responses without hiding programmer defects.
family: rails
---

# Controller Exception Boundary

## Problem

Controllers need predictable responses for expected domain failures, but broad rescue logic can hide defects and destroy observability.

## Use when

- adding rescue_from
- mapping domain errors to status codes
- standardizing controller error representations
- reviewing exception handling.

## Do not use when

- a central application error boundary already owns the behavior
- the exception has no stable HTTP meaning.

## Repository inspection

Inspect global error handling, ApplicationController, observability/error reporting, API error schema, and request tests.

## Implementation procedure

1. List expected exception classes.
2. Map each to an intentional HTTP status and representation.
3. Keep programmer defects unhandled by local rescue logic.
4. Preserve correlation/error context for observability.
5. Test expected exceptions and unexpected exceptions separately.

## Example

```ruby
class ApplicationController < ActionController::Base
  # Expected domain failures map to stable responses; everything else
  # propagates to the error reporter and the 500 page.
  rescue_from Orders::InvalidState, with: :conflict
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def conflict(error)
    render json: { error: "invalid_state", detail: error.message }, status: :conflict
  end

  def bad_request(error)
    render json: { error: "bad_request", param: error.param }, status: :bad_request
  end
end
# Not: rescue_from StandardError, which hides defects behind a 200/422.
```

## Failure modes

- rescuing StandardError broadly
- converting authorization failures into successful responses
- exposing exception messages or stack traces in production
- double-reporting a globally handled exception.

## Testing

Assert status, body/content type, security-sensitive redaction, and observability behavior where practical.

## Review checklist

- [ ] exception classes are intentional
- [ ] mappings are stable
- [ ] unexpected errors still fail correctly
- [ ] sensitive details are not exposed
- [ ] error reporting is not duplicated

## Related skills

rails-action-controller, rails-observability, rails-security, rails-api-integration
