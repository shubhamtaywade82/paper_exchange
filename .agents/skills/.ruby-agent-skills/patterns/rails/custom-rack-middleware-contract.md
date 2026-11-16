---
name: custom-rack-middleware-contract
description: Define a small, explicit custom Rack middleware responsibility.
family: rails
---
# Custom Rack Middleware Contract

## Problem
Custom middleware often becomes an unbounded application layer with hidden state and unclear ownership.

## Use when
A repository genuinely needs cross-cutting Rack behavior not already provided by existing middleware.

## Do not use when
A controller/service/policy already owns the behavior or an existing middleware satisfies it.

## Repository inspection
Inspect existing middleware, Rails hooks, dependencies, and the desired request/response boundary.

## Implementation procedure
Use initialize(app,...), keep one responsibility, make configuration explicit, avoid domain state, and return/delegate according to Rack semantics.

## Example

```ruby
# Narrow and stateless: adds one header, never touches domain objects, and
# preserves the [status, headers, body] contract.
class ServerTimingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
    headers["server-timing"] = "app;dur=#{elapsed_ms}"
    [status, headers, body]
  end
end

# config/application.rb
#   config.middleware.insert_after ActionDispatch::RequestId, ServerTimingMiddleware
```

## Failure modes
God middleware, duplicated framework behavior, hidden global state, and business logic leakage.

## Testing
Test middleware directly with Rack::MockRequest or the repository's equivalent and add integration coverage when stack registration matters.

## Review checklist
[ ] one responsibility
[ ] downstream app explicit
[ ] no domain ownership
[ ] direct contract test

## Related skills
rails-rack-middleware-engineering, ruby-object-composition, ruby-dependency-injection
