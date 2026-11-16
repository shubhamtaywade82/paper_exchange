---
name: authorization-service-boundary
description: Protect security-sensitive application services when they can be invoked outside controllers.
family: rails
---
# Authorization Service Boundary

## Problem
A service trusts controller authorization even though other callers can invoke it.

## Use when
A workflow is reusable from controllers, jobs, CLI tasks, events, or other services.

## Structure
Require an actor/capability context or authorize the application operation at the service boundary.

## Example

```ruby
# The service authorizes its own operation, because jobs, the console, and
# the API call it without going through the controller.
class Projects::Transfer
  def initialize(project, to_account:, actor:)
    @project = project
    @to_account = to_account
    @actor = actor
  end

  def call
    raise Authorization::Forbidden unless ProjectPolicy.new(@actor.membership_in(@project.account)).allowed?(:transfer)
    raise Authorization::Forbidden unless @actor.member_of?(@to_account)

    @project.update!(account: @to_account)
  end
end
```

## Failure modes
Direct service invocation bypass, ambient current-user dependency, and conflicting duplicate checks.

## Testing
Invoke the service directly with authorized and unauthorized actors.

## Review checklist
The service security contract is explicit.

## Do not use when

Do not introduce this pattern when direct repository policy or scope logic is clearer and complete.

## Repository inspection

Inspect the existing authorization mechanism, callers, resource ownership, tenant scope, tests, and resolved framework versions.

## Implementation procedure

Define the boundary, adapt it to existing repository conventions, preserve failure semantics, and add regression tests.

## Related skills

rails-authorization, rails-security, rails-active-record, rails-test-engineering
