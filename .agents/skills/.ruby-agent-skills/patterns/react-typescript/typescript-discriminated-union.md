---
name: typescript-discriminated-union
description: Model mutually exclusive TypeScript states with an explicit discriminant.
family: react-typescript
---

# Typescript Discriminated Union

## Problem
The domain has distinct states that must not be represented by arbitrary flag combinations.

## Use when
Designing state flags would permit combinations that the domain forbids.

## Do not use when
Do not activate simply when Designing state flags would permit combinations that the domain forbids. 

## Repository inspection
Inspect all current flags and consumers of the state.

## Implementation procedure
Define a stable discriminant and one shape per valid state; keep shared fields common and state-specific fields narrow.

## Example

```ts
// Before: { loading: boolean; error?: string; data?: User } allows loading+error+data at once.
// After: exactly one state at a time, each with only the fields it has.
type User = { id: string; name: string };

export type UserState =
  | { status: "loading" }
  | { status: "error"; error: string }
  | { status: "loaded"; user: User };

export function title(state: UserState): string {
  switch (state.status) {
    case "loading":
      return "Loading…";
    case "error":
      return `Error: ${state.error}`;
    case "loaded":
      return state.user.name;
  }
}
```

## Failure modes
Overlapping variants, optional-everything objects, and boolean flag matrices.

## Testing
Typecheck narrowing branches and test every state plus impossible-state rejection where tooling supports it.

## Review checklist
Is the discriminant stable? Are invalid combinations unrepresentable?

## Related skills
typescript-type-design,typescript-core-engineering
