---
name: api-authorization-boundary
description: Enforce authorization explicitly at API resource boundaries.
family: rails
---
# API Authorization Boundary

## Problem
An API authenticates a caller but does not consistently authorize resource actions.

## Structure
Authenticate, establish tenant/context, resolve authorized resource scope, authorize action, then mutate/read.

## Example

```ruby
class Api::V1::ProjectsController < Api::BaseController
  # authenticate -> establish tenant -> scope lookup -> authorize action -> act
  before_action :authenticate_api_token!

  def update
    project = current_tenant.projects.find(params[:id]) # 404 outside the tenant
    authorize! :update, project                          # 403 for a visible but forbidden action
    project.update!(params.expect(project: [:name]))
    render json: ProjectSerializer.new(project)
  end
end
```

## Failure modes
Bearer token treated as permission, IDOR through direct lookup, inconsistent status/error semantics, and frontend-only permission checks.

## Testing
Exercise valid, invalid, cross-tenant, and stale-permission requests.

## Use when

Use this pattern when the named security boundary is part of the requested change.

## Do not use when

Do not introduce this pattern when a simpler repository-consistent boundary already proves the required contract.

## Repository inspection

Inspect the existing authorization mechanism, entry points, resource ownership, tenant scope, tests, and versioned dependencies.

## Implementation procedure

Define the authoritative boundary, adapt to repository conventions, preserve denial semantics, and add focused regression coverage.

## Review checklist

[ ] authoritative mechanism preserved
[ ] bypass paths reviewed
[ ] tenant/resource scope explicit
[ ] rejection behavior tested

## Related skills

rails-authorization, rails-authentication, rails-security, rails-test-engineering
