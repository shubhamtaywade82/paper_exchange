---
name: engine-authorization-composition
description: Engine Authorization Composition Contract
family: security
---
# Engine Authorization Composition Contract

## Problem
Host application authorization can be assumed to cover engine routes when it does not.

## Use when
A mountable or isolated engine exposes protected resources.

## Do not use when
An engine has no protected routes or resources.

## Repository inspection
Inspect engine routes, controllers, policies, mount boundaries, host authentication, and namespace isolation.

## Implementation procedure
Define engine-side authorization explicitly and integrate host authentication/context deliberately.

## Example

```ruby
# The engine does not assume the host protected its routes: it requires an
# authorization hook and calls it on every request.
module Reports
  class ApplicationController < ActionController::Base
    before_action :authorize_reports_access!

    private

    def authorize_reports_access!
      allowed = Reports.config.authorize.call(self)
      head :forbidden unless allowed
    end
  end
end

# host: config/initializers/reports.rb
#   Reports.config.authorize = ->(controller) { controller.current_user&.admin? }
```

## Failure modes
Engine route bypass, namespace confusion, host/engine policy divergence.

## Testing
Test mounted and direct engine routes with authorized and unauthorized contexts.

## Review checklist
[ ] engine routes protected [ ] host context explicit [ ] policy ownership

## Related skills
rails-cross-boundary-authorization-security, rails-engines-railties-engineering, rails-authorization