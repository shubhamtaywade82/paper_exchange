---
name: typescript-type-before-wrapper
description: TypeScript Type Before Wrapper
family: stack-minimality
---
# TypeScript Type Before Wrapper

## Problem
A runtime abstraction is unnecessary when the requirement is only a compile-time contract.

## Use when
Designing shared types, result shapes, identifiers, and variants.

## Do not use when
Dynamic data crosses an untrusted boundary and needs runtime parsing or validation.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Prefer interfaces, type aliases, utility types, discriminated unions, and generics. Use runtime schemas at dynamic boundaries only.

## Example

```ts
// Before: class Email { constructor(private value: string) {} toString() { return this.value; } }
// used only so function signatures cannot mix up strings — a runtime wrapper
// for a compile-time need.

// After: a type-level distinction with zero runtime cost.
type Email = string & { readonly __brand: "Email" };

export function asEmail(value: string): Email {
  if (!value.includes("@")) throw new Error("invalid email");
  return value as Email;
}

export function sendReceipt(to: Email, body: string): string {
  return `${to}: ${body}`;
}
```

## Failure modes
Runtime wrappers for static concerns and type assertions used as validation.

## Testing
Type-check the project and test dynamic boundary parsing.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
typescript-type-design, typescript-runtime-contracts, stack-minimality
