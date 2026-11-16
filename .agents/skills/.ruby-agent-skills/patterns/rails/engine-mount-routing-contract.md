---
name: engine-mount-routing-contract
description: Engine Mount and Routing Contract
family: rails
---
# Engine Mount and Routing Contract

## Problem
An engine can be internally correct but incorrectly exposed by the host mount and route integration.

## Use when
Mounting or changing engine routes.

## Do not use when
An engine is not HTTP-facing.

## Repository inspection
Inspect engine routes, host routes, mount points, helper usage, constraints, and authorization boundaries.

## Implementation procedure
Define mount path, helper semantics, constraints, and host security expectations.

## Example

```ruby
Rails.application.routes.draw do
  # Mount point, constraint, and precedence are the host's decision.
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/admin/sidekiq"
  end
  mount Blog::Engine, at: "/blog", as: "blog"
end

# Host views link with the engine's route proxy:
#   link_to "Blog", blog.root_path
```

## Failure modes
Route collisions, unexpected exposure, broken URL generation, missing authorization.

## Testing
Test engine routes and host-mounted routes in the dummy/host app.

## Review checklist
[ ] mount explicit [ ] helpers verified [ ] exposure reviewed [ ] auth boundary

## Related skills
rails-engines-railties-engineering, rails-routing, rails-authorization