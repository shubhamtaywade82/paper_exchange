---
name: fullstack-existing-boundary-before-adapter
description: Fullstack Existing Boundary Before Adapter
family: stack-minimality
---
# Fullstack Existing Boundary Before Adapter

## Problem
A new adapter can duplicate a boundary the application already owns.

## Use when
Connecting React to Rails or adding an external integration.

## Do not use when
Two incompatible external contracts genuinely need isolation or the adapter has multiple implementations.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Trace the React client, Rails controller/service/serializer, error contract, and external provider. Extend existing boundaries when compatible.

## Example

```ts
// The app already has one API client that handles auth, CSRF, and errors.
declare const apiClient: { get<T>(path: string): Promise<T> };

type Invoice = { id: string; totalCents: number };

// Before: a second adapter re-implementing fetch, headers, and error mapping.
// export class InvoiceAdapter { async list() { const r = await fetch("/api/invoices", { headers: ... }); ... } }

// After: reuse the owner of that boundary.
export function listInvoices(): Promise<Invoice[]> {
  return apiClient.get<Invoice[]>("/api/invoices");
}
```

## Failure modes
Adapter-over-adapter stacks, duplicate error normalization, and drifting client/server contracts.

## Testing
Test the API contract and the real translation boundary.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
rails-api-integration, react-data-fetching, typescript-runtime-contracts, stack-minimality
