---
name: composition-over-inheritance
description: Use when behavior can be assembled from collaborators and inheritance would mainly provide implementation reuse.
family: ruby-design
---

# Composition Over Inheritance

## Problem

A subtype relationship is being used primarily to reuse code rather than to model genuine substitutability.

## Use when

- behavior varies independently from object identity
- collaborators can express the variation explicitly
- inheritance would create a growing hierarchy
- runtime configuration selects behavior

## Do not use when

- a real subtype contract already exists
- framework inheritance is required by the repository
- composition would add unnecessary indirection

## Repository inspection

Inspect the current inheritance hierarchy, overridden methods, super calls, lifecycle hooks, and callers that depend on subtype behavior.

## Structure

~~~ruby
class Report
  def initialize(formatter)
    @formatter = formatter
  end

  def render(data)
    @formatter.render(data)
  end
end
~~~

The collaborator should own the behavior that genuinely varies.

## Implementation procedure

1. Identify what varies.
2. Separate invariant behavior from variable behavior.
3. Define the smallest collaborator interface.
4. Inject the collaborator using existing repository conventions.
5. Preserve observable behavior.
6. Remove inheritance only after regression coverage exists.

## Failure modes

- composition used for every tiny variation
- excessive dependency injection
- collaborator interfaces broader than needed
- breaking subtype contracts during refactoring

## Testing

Characterize existing subtype behavior before changing the hierarchy. Test the composed object and each meaningful collaborator.

## Review checklist

- [ ] inheritance relationship is genuinely substitutable
- [ ] variable behavior identified
- [ ] collaborator interface is small
- [ ] dependency is explicit
- [ ] behavior is regression-covered

## Related skills

- ruby-oop
- ruby-modules-mixins
- ruby-clean-code
- ruby-tdd-refactoring
