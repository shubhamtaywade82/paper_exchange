---
name: engine-host-override-contract
description: Engine Host Override Contract
family: rails
---
# Engine Host Override Contract

## Problem
Host customizations can become brittle monkey patches with undocumented assumptions.

## Use when
An application intentionally extends or overrides engine behavior.

## Do not use when
The host is not customizing engine behavior.

## Repository inspection
Inspect documented extension points, decorators, inheritance, callbacks, and host patches.

## Implementation procedure
Prefer explicit extension points and narrow composition/decorators; document load order when unavoidable.

## Example

```ruby
# The engine publishes an explicit extension point instead of expecting the
# host to reopen its classes.
module Blog
  mattr_accessor :post_decorators, default: []

  class PostPresenter
    def initialize(post) = @post = post

    def title
      Blog.post_decorators.reduce(@post.title) { |title, decorator| decorator.call(title, @post) }
    end
  end
end

# host: config/initializers/blog.rb
#   Blog.post_decorators << ->(title, post) { post.sponsored? ? "#{title} (sponsored)" : title }
```

## Failure modes
Boot-order bugs, duplicate methods, upgrade breakage, hidden host coupling.

## Testing
Test the override independently and against engine baseline behavior.

## Review checklist
[ ] extension point explicit [ ] patch narrow [ ] load order verified [ ] upgrade risk

## Related skills
rails-engines-railties-engineering, ruby-object-composition, rails-initialization-configuration-engineering