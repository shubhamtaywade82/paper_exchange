---
name: engine-dummy-app-testing
description: Engine Dummy Application Testing Contract
family: rails
---
# Engine Dummy Application Testing Contract

## Problem
Engine unit tests can miss mounting, configuration, host integration, and lifecycle failures.

## Use when
Changing engine-host integration or public engine behavior.

## Do not use when
Purely internal engine object behavior.

## Repository inspection
Inspect dummy app routes/configuration, fixtures, engine test helpers, and integration tests.

## Implementation procedure
Use a representative dummy application to exercise realistic host integration.

## Example

```ruby
# test/dummy is a minimal host that mounts the engine; integration tests go
# through real routing, middleware, and configuration.
require "test_helper"

class ReportsEngineMountTest < ActionDispatch::IntegrationTest
  include ReportsEngine::Engine.routes.url_helpers

  test "mounted index requires the host's authorization hook" do
    ReportsEngine.config.authorize = ->(_controller) { false }
    get "/reports"
    assert_response :forbidden
  ensure
    ReportsEngine.config.authorize = ->(_controller) { true }
  end
end
```

## Failure modes
Tests pass in isolation but fail when mounted or configured in a host.

## Testing
Test mount, routes, configuration, boot, and representative engine behavior.

## Review checklist
[ ] dummy app representative [ ] mount tested [ ] config tested [ ] boot tested

## Related skills
rails-engines-railties-engineering, rails-test-engineering