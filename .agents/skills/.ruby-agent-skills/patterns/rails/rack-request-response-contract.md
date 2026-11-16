---
name: rack-request-response-contract
description: Preserve the Rack environment and response tuple contract at a middleware boundary.
family: rails
---
# Rack Request Response Contract

## Problem
A middleware can accidentally return an invalid response or corrupt the downstream environment/body lifecycle.

## Use when
Implementing or reviewing a Rack middleware boundary.

## Do not use when
Changing ordinary controller behavior without a Rack boundary.

## Repository inspection
Inspect Rack/Rails versions, existing middleware, env keys, response wrappers, and Rack request tests.

## Implementation procedure
Keep env mutation explicit, delegate exactly once when required, return a valid status/headers/body tuple, and preserve body ownership.

## Example

```ruby
class ContentSecurityHeaders
  def initialize(app) = @app = app

  def call(env)
    status, headers, body = @app.call(env)
    # Rack 3: headers are a mutable Hash with lowercase keys; body is passed through
    # untouched so streaming and body.close still reach the server.
    headers["x-content-type-options"] ||= "nosniff"
    [status, headers, body]
  end
end

# Wrong: body.each { ... } then returning body — consumes a streaming body
# and skips close. Wrong: env["PATH_INFO"] = "/rewritten" — mutates downstream routing.
```

## Failure modes
Invalid response shape, accidental double delegation, body leaks, and incompatible env mutations.

## Testing
Exercise normal delegation, short-circuit responses, headers, status, and body closure where applicable.

## Review checklist
[ ] response contract explicit
[ ] env mutations bounded
[ ] body ownership verified
[ ] delegation semantics tested

## Related skills
rails-rack-middleware-engineering, rails-test-engineering
