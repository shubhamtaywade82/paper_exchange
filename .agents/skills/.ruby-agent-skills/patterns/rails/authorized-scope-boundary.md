---
name: authorized-scope-boundary
description: Constrain collection queries to resources the actor may enumerate.
family: rails
---
# Authorized Scope Boundary

## Problem
An endpoint authorizes individual records but loads an unbounded collection first.

## Use when
Index, search, export, report, association, or dashboard results are actor-dependent.

## Structure
Build the authorized relation first, then apply request filters and pagination.

## Example

```ruby
class ProjectsController < ApplicationController
  def index
    # Authorized relation first, then request filters, then pagination.
    scope = policy_scope(Project)
    scope = scope.where(status: params[:status]) if Project.statuses.key?(params[:status])
    @projects = scope.order(updated_at: :desc).page(params[:page]).per(25)
  end
end

class ProjectPolicy::Scope < ApplicationPolicy::Scope
  def resolve = scope.where(account_id: user.account_id)
end
```

## Implementation procedure
Establish actor/tenant context, build the authorized relation, apply filters and ordering, then paginate.

## Failure modes
Load-all-then-filter, client-provided tenant filtering, and inconsistent index/show authorization.

## Testing
Assert unauthorized records are absent and cross-tenant records cannot be enumerated.

## Review checklist
Authorization is enforced in the query boundary, not presentation.

## Do not use when

Do not introduce this pattern when direct repository policy or scope logic is clearer and complete.

## Repository inspection

Inspect the existing authorization mechanism, callers, resource ownership, tenant scope, tests, and resolved framework versions.

## Related skills

rails-authorization, rails-security, rails-active-record, rails-test-engineering
