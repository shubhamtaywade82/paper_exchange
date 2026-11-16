---
name: middleware-thread-safety
description: Keep middleware safe under concurrent request execution.
family: rails
---
# Middleware Thread Safety

## Problem
Shared mutable middleware state can race across threads, fibers, or processes.

## Use when
Middleware stores counters, caches, configuration, or reusable collaborators across requests.

## Do not use when
All state is immutable configuration or request-local state.

## Repository inspection
Inspect server concurrency, middleware object lifetime, shared variables, synchronization, and process topology.

## Implementation procedure
Move request state into local variables, make shared state immutable or explicitly synchronized, and choose process-safe stores for distributed limits.

## Example

```ruby
class RequestCounter
  def initialize(app)
    @app = app
    @count = Concurrent::AtomicFixnum.new(0) # shared across Puma threads: atomic
  end

  def call(env)
    # Per-request state lives in locals or env, never in instance variables.
    request_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    env["app.request_number"] = @count.increment
    status, headers, body = @app.call(env)
    headers["server-timing"] = "app;dur=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_started_at) * 1000).round}"
    [status, headers, body]
  end
end
# Wrong: @current_path = env["PATH_INFO"]  (races between concurrent requests)
```

## Failure modes
Race conditions, cross-request leakage, deadlocks, process-local inconsistency, and stale state.

## Testing
Use concurrent request tests where shared state exists and run relevant thread-safety checks.

## Review checklist
[ ] no request state in globals
[ ] synchronization justified
[ ] process model considered
[ ] concurrent test

## Related skills
rails-rack-middleware-engineering, ruby-concurrency, rails-performance
