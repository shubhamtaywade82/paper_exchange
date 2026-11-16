---
name: authorization-denial-contract
description: Authorization Denial Contract
family: security
---
# Authorization Denial Contract

## Problem
Security boundaries leak inconsistent denial semantics that expose existence or confuse clients/operators.

## Use when
Multiple entry points need consistent forbidden/not-found/rejected behavior.

## Do not use when
A boundary intentionally exposes public existence and uses one stable response contract.

## Repository inspection
Inspect existing 403/404, policy failures, job discard, channel rejection, and task exit semantics.

## Implementation procedure
Define denial mapping by threat model and preserve it across execution surfaces.

## Example

```ruby
class ApplicationController < ActionController::Base
  # Not in your tenant: 404 (don't confirm it exists).
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  # Visible to you but not allowed: 403, with the same body shape everywhere.
  rescue_from Authorization::Forbidden, with: :forbidden

  private

  def not_found = render(json: { error: "not_found" }, status: :not_found)
  def forbidden = render(json: { error: "forbidden" }, status: :forbidden)
end
```

## Failure modes
Existence leaks, inconsistent client behavior, retries on permanent denial, or silent task success.

## Testing
Test denial semantics per boundary and ensure no sensitive detail leaks.

## Review checklist
[ ] deliberate denial [ ] existence considered [ ] retry semantics [ ] no sensitive detail

## Related skills
rails-cross-boundary-authorization-security, rails-authorization