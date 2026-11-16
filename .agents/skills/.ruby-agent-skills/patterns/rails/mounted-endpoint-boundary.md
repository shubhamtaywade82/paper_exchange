---
name: mounted-endpoint-boundary
description: Use when mounting a Rack application or Rails engine into the application's route set.
family: rails
---

# Mounted Endpoint Boundary

## Problem

A mounted endpoint introduces a second dispatch surface with its own ownership, helpers, middleware, and failure behavior.

## Use when

- mounting Rack application endpoints;
- mounting a Rails engine;
- reviewing route precedence around a mount.

## Do not use when

- routing only to a normal Rails controller action.

## Repository inspection

Inspect mount path, component ownership, helper/proxy behavior, authentication/authorization, middleware, and route-table order.

## Implementation procedure

1. Identify the mounted component owner and trust boundary.
2. Choose the mount path deliberately.
3. Verify helper/proxy behavior.
4. Preserve authentication and authorization boundaries.
5. Inspect route precedence around the mount.
6. Add dispatch and failure tests where appropriate.

## Example

```ruby
Rails.application.routes.draw do
  # The mount is an exposure decision: authentication happens before dispatch.
  authenticate :user, ->(user) { user.admin? } do
    mount MissionControl::Jobs::Engine, at: "/admin/jobs"
  end

  # A Rack app has no Rails controller callbacks; it owns its own errors.
  mount WebhooksApp.new, at: "/webhooks/provider", via: :post
end

# test/integration/admin_mount_test.rb
class AdminMountTest < ActionDispatch::IntegrationTest
  test "non-admins cannot reach the jobs dashboard" do
    sign_in users(:member)
    get "/admin/jobs"
    assert_response :not_found
  end
end
```

## Failure modes

- mounted route shadows application routes;
- auth boundary assumed to transfer automatically;
- helper exposes unintended internals;
- failure behavior untested.

## Testing

Verify mounted requests, helper/proxy behavior, route precedence, and failure behavior where supported.

## Review checklist

- [ ] owner explicit
- [ ] mount path intentional
- [ ] route order reviewed
- [ ] auth boundary explicit
- [ ] helper/proxy behavior tested

## Related skills

rails-routing, rails-security, rails-test-engineering
