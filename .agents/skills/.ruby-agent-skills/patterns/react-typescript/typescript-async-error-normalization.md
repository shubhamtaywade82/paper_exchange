---
name: typescript-async-error-normalization
description: Normalize asynchronous failures into a small typed contract at the integration boundary.
family: react-typescript
---

# Typescript Async Error Normalization

## Problem
Multiple async providers expose different failure shapes.

## Use when
A provider already exposes the exact domain error contract and no translation is needed.

## Do not use when
Do not activate simply when A provider already exposes the exact domain error contract and no translation is needed. 

## Repository inspection
Inspect promise rejection, network client errors, cancellation, and caller expectations.

## Implementation procedure
Map transport/provider failures to deliberate domain categories while preserving cancellation semantics.

## Example

```ts
// Different providers fail differently; callers see one error shape.
export type AppError = { kind: "network" | "timeout" | "http" | "unknown"; message: string; status?: number };

export function normalizeError(error: unknown): AppError {
  if (error instanceof DOMException && error.name === "AbortError") return { kind: "timeout", message: "Request timed out" };
  if (error instanceof TypeError) return { kind: "network", message: "Network unavailable" };
  if (typeof error === "object" && error !== null && "status" in error && typeof error.status === "number") {
    return { kind: "http", message: `HTTP ${error.status}`, status: error.status };
  }
  return { kind: "unknown", message: error instanceof Error ? error.message : "Unexpected error" };
}

export async function safely<T>(run: () => Promise<T>): Promise<{ ok: true; value: T } | { ok: false; error: AppError }> {
  try {
    return { ok: true, value: await run() };
  } catch (error: unknown) {
    return { ok: false, error: normalizeError(error) };
  }
}
```

## Failure modes
Catching everything as one generic error, retrying non-retryable errors, or losing cancellation identity.

## Testing
Test timeout, cancellation, provider error, malformed response, and success paths.

## Review checklist
Can callers distinguish retryable, terminal, and cancelled work?

## Related skills
typescript-runtime-contracts,typescript-core-engineering
