---
name: typescript-generic-result
description: Use a focused generic result contract when success and failure data vary while the protocol stays stable.
family: react-typescript
---

# Typescript Generic Result

## Problem
Several APIs share a success/failure protocol with different payload types.

## Use when
Generics would obscure a single concrete contract or only save a few duplicated lines.

## Do not use when
Do not activate simply when Generics would obscure a single concrete contract or only save a few duplicated lines. 

## Repository inspection
Inspect existing Result, Promise, error, and response conventions.

## Implementation procedure
Define the smallest generic relationship and preserve exhaustive narrowing for success/failure.

## Example

```ts
// One success/failure protocol shared by many APIs with different payloads.
export type Result<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });

export function map<T, U, E>(result: Result<T, E>, transform: (value: T) => U): Result<U, E> {
  return result.ok ? ok(transform(result.value)) : result;
}

export function parsePort(raw: string): Result<number> {
  const port = Number(raw);
  return Number.isInteger(port) && port > 0 && port < 65536 ? ok(port) : err(`invalid port: ${raw}`);
}

const doubled = map(parsePort("8080"), (port) => port * 2);
```

## Failure modes
Generic wrappers around every function, unconstrained type parameters, and nested generic aliases.

## Testing
Compile representative success/failure assignments and test runtime behavior at boundaries.

## Review checklist
Does the type parameter express a real relationship?

## Related skills
typescript-type-design,typescript-core-engineering
