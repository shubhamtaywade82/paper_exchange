---
name: engine-boundary-contract
description: Engine Boundary Contract
family: rails
---
# Engine Boundary Contract

## Problem
Host ownership and engine ownership become unclear when an extension boundary is implicit.

## Use when
Introducing or modifying a Rails Engine.

## Do not use when
Ordinary application modules without an Engine boundary.

## Repository inspection
Inspect engine class, gemspec, namespace, host integration, and lifecycle hooks.

## Implementation procedure
Define engine-owned behavior, host-owned behavior, integration points, and compatibility boundaries.

## Example

```ruby
# The engine's supported surface: its mount point, its config API, and one
# public service. Everything else is private to the engine.
module Blog
  class Engine < ::Rails::Engine
    isolate_namespace Blog
  end

  mattr_accessor :author_class, default: "User"

  def self.publish(post_id) = Posts::Publish.call(Post.find(post_id))
end

# host
#   mount Blog::Engine, at: "/blog"
#   Blog.author_class = "Staff"
```

## Failure modes
Hidden host coupling, lifecycle leakage, and unreviewable extension behavior.

## Testing
Test engine boot plus one host integration path.

## Review checklist
[ ] ownership explicit [ ] integration points explicit [ ] compatibility reviewed

## Related skills
rails-engines-railties-engineering, rails-initialization-configuration-engineering