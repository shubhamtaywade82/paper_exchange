---
name: cross-cutting-ownership-contract
description: Cross-Cutting Ownership Contract
family: architecture
---
# Cross-Cutting Ownership Contract

## Problem
Cross-cutting concerns get duplicated when no subsystem owns their policy and integration contract.

## Use when
Introducing shared authentication, authorization, observability, reliability, configuration, or infrastructure behavior.

## Do not use when
A concern is purely local to one domain and has no cross-boundary behavior.

## Repository inspection
Inspect existing skills/components, middleware, controllers, jobs, event consumers, and configuration.

## Implementation procedure
Define one policy owner plus explicit adapters at framework boundaries; keep domain code focused on business responsibility.

## Example

```ruby
# One owner for request correlation: a concern that every controller and job
# base class includes, instead of each team adding its own request-id code.
module Correlation
  extend ActiveSupport::Concern

  included do
    if self <= ActionController::Base
      before_action { Current.request_id = request.request_id }
    else
      around_perform { |job, block| Current.set(request_id: job.arguments.last.try(:[], :request_id)) { block.call } }
    end
  end
end

class ApplicationController < ActionController::Base
  include Correlation
end
```

## Failure modes
Parallel implementations, inconsistent semantics, missing enforcement at alternate entry points.

## Testing
Test representative boundaries and the shared policy.

## Review checklist
[ ] policy owner [ ] adapters [ ] alternate paths [ ] semantics consistent

## Related skills
rails-staff-principal-architecture, rails-cross-boundary-authorization-security