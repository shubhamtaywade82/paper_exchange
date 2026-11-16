# Implementation Patterns

Patterns are concrete implementation shapes that agents can apply after selecting skills.

A skill answers:

> When and why should the agent use this approach?

A pattern answers:

> What is a safe, conventional implementation shape when that approach is appropriate?

Patterns are not mandatory templates. Repository evidence and task requirements always take precedence.

## Pattern families

### Ruby design

- value object
- service object
- application service
- command
- strategy object
- policy object
- composition over inheritance
- adapter
- dependency injection
- external API client
- Ruby gem boundary
- metaprogramming boundary
- null object
- factory
- builder
- decorator
- facade
- repository
- specification
- state object
- service composition

### Rails

- query object
- form object
- policy boundary
- transaction boundary
- request flow
- REST resource
- scaffold lifecycle
- presenter

### Testing and algorithms

- regression tests
- two pointers
- frequency maps

## Pattern selection matrix

| Problem shape | Candidate |
|---|---|
| Meaningful immutable value | value object |
| One application workflow | service object / command |
| Shared service entry-point convention | application service |
| Reusable business decision | policy object / specification |
| Interchangeable algorithm | strategy object |
| External interface mismatch | adapter |
| Replaceable collaborator | dependency injection |
| Add behavior around a stable interface | decorator |
| Hide a complex subsystem | facade |
| Vary object construction | factory |
| Complex staged construction | builder |
| Safe no-op collaborator | null object |
| Complex persistence boundary | repository / query object |
| State-specific behavior | state object |
| Presentation transformation | presenter |

A matrix entry is a candidate, not an automatic architectural verdict.

## Selection rule

Do not introduce a pattern because its name sounds sophisticated.

Use the smallest pattern that:

1. solves the actual responsibility problem,
2. matches repository conventions,
3. improves testability or changeability,
4. does not create unnecessary indirection.

## Pattern composition

Patterns can compose when each solves a different responsibility.

For example:

    Service Object
      + Strategy
      + Adapter
      + Value Object

or:

    Rails endpoint
      + REST resource
      + Authentication boundary
      + Form Object
      + Service Object
      + Transaction boundary

Do not stack patterns merely to make an architecture look sophisticated.

## Pattern restraint

Negative pattern selection is intentional.

A task that can be solved cleanly with one method should not produce a factory, service, strategy, and repository merely because those patterns exist.

Before applying a pattern, ask:

- Is there a real responsibility boundary?
- Does the pattern reduce coupling or improve testability?
- Does the repository already use it?
- Would a direct implementation be clearer?

## Evidence order

1. explicit task requirement
2. existing repository pattern
3. framework/runtime constraints
4. skill guidance
5. these patterns
6. generic preference

Book-derived patterns are guidance for recurring problem shapes, not architecture mandates.
