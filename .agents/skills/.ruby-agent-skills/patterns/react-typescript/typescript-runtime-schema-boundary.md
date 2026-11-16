---
name: typescript-runtime-schema-boundary
description: Validate unknown external data once before treating it as typed application data.
family: react-typescript
---

# Typescript Runtime Schema Boundary

## Problem
JSON, HTTP, storage, environment, or dynamic JavaScript crosses a trust boundary.

## Use when
The input is already produced by a trusted in-process contract with no runtime uncertainty.

## Do not use when
Do not activate simply when The input is already produced by a trusted in-process contract with no runtime uncertainty. 

## Repository inspection
Inspect where data enters, current schema utilities, and error handling.

## Implementation procedure
Parse unknown input, validate at the boundary, normalize if required, and pass trusted data inward.

## Example

```ts
// Environment and JSON arrive as untyped data; they are parsed once at the
// boundary and the rest of the code receives a checked type.
export type Config = { apiUrl: URL; timeoutMs: number };

export function loadConfig(env: Record<string, string | undefined>): Config {
  const rawUrl = env["API_URL"];
  const rawTimeout = env["API_TIMEOUT_MS"] ?? "5000";
  if (!rawUrl) throw new Error("API_URL is required");

  const apiUrl = new URL(rawUrl); // throws on malformed URLs
  if (apiUrl.protocol !== "https:") throw new Error("API_URL must use https");

  const timeoutMs = Number(rawTimeout);
  if (!Number.isInteger(timeoutMs) || timeoutMs <= 0 || timeoutMs > 60_000) {
    throw new Error("API_TIMEOUT_MS must be an integer between 1 and 60000");
  }
  return { apiUrl, timeoutMs };
}
```

## Failure modes
Type assertions as validation, repeated validation in every consumer, and unsafe logging of payloads.

## Testing
Test malformed, missing, extra, and version-drift input.

## Review checklist
Is runtime validation owned by one deliberate boundary?

## Related skills
typescript-runtime-contracts,typescript-core-engineering
