---
name: authorization-matrix
description: Specify who may perform which actions on which resources within which tenant or privilege scope.
family: rails
---

# Authorization Matrix

## Problem

Authorization rules are distributed across controllers, policies, queries, and UI assumptions, allowing alternate paths to disagree.

## Use when

Roles, ownership, tenant scope, delegation, or privileged administrative actions materially affect access.

## Do not use when

The resource is deliberately public and has no access-control boundary.

## Repository inspection

Inspect authentication, policy objects, resource ownership, tenant scope, controllers, jobs, exports, callbacks, and admin paths.

## Implementation procedure

1. Enumerate actors/roles.
2. Enumerate resource types.
3. Enumerate actions.
4. Add tenant/ownership constraints.
5. Identify privileged exceptions.
6. Choose one authoritative policy boundary.
7. Apply the policy to every execution path.
8. Add allow/deny tests for normal and alternate paths.

## Example

```ruby
# One table drives the policy and the tests, so every role/action pair is
# decided on purpose.
class ProjectPolicy
  MATRIX = {
    viewer: %i[read],
    editor: %i[read update],
    owner: %i[read update destroy transfer]
  }.freeze

  def initialize(membership) = @role = membership&.role&.to_sym

  def allowed?(action) = MATRIX.fetch(@role, []).include?(action)
end

class ProjectPolicyTest < ActiveSupport::TestCase
  ProjectPolicy::MATRIX.each_key do |role|
    %i[read update destroy transfer].each do |action|
      test "#{role} #{action}" do
        expected = ProjectPolicy::MATRIX.fetch(role).include?(action)
        assert_equal expected, ProjectPolicy.new(Membership.new(role: role)).allowed?(action)
      end
    end
  end
end
```

## Failure modes

- authenticated means authorized
- controller protected but job/export is not
- IDOR/BOLA through direct record lookup
- admin bypass becomes tenant bypass
- policy differs by endpoint

## Testing

Test owner, unrelated user, privileged user, cross-tenant access, background job, and export/download paths as applicable.

## Review checklist

- [ ] actor/resource/action matrix
- [ ] tenant scope explicit
- [ ] privileged exceptions explicit
- [ ] alternate paths covered
- [ ] denial tests present

## Related skills

- rails-security-engineering
- rails-security
- rails-authentication
- rails-test-engineering
