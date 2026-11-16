---
name: policy-object-boundary
description: Encapsulate a coherent authorization decision in a small policy object.
family: rails
---
# Policy Object Boundary

## Problem
Permission rules are scattered across callers.

## Use when
A resource/action has a stable, testable authorization contract.

## Do not use when
The rule is a single repository-local predicate with no meaningful boundary.

## Structure
A policy receives actor, resource, and explicit context and answers a decision. It does not mutate state or perform unrelated I/O.

## Example

```ruby
class DocumentPolicy
  def initialize(user, document, context: {})
    @user = user
    @document = document
    @context = context
  end

  # Decisions only: no queries beyond what the inputs already load, no mutations.
  def update?
    return false unless @user && same_account?
    @user.admin? || @document.owner_id == @user.id
  end

  def destroy? = update? && !@document.locked?

  private

  def same_account? = @document.account_id == @user.account_id
end

# Callers: controllers, jobs, tasks, and consumers all ask the same object.
```

## Implementation procedure
Keep action predicates narrow, name domain concepts explicitly, and compose shared predicates carefully.

## Failure modes
God policies, hidden global context, policy-side effects, and duplicated domain invariants.

## Testing
Unit-test decisions independently and verify at least one real application boundary.

## Review checklist
Explicit inputs, deterministic decision, no side effects, clear action semantics.

## Repository inspection

Inspect the existing authorization mechanism, callers, resource ownership, tenant scope, tests, and resolved framework versions.

## Related skills

rails-authorization, rails-security, rails-active-record, rails-test-engineering
