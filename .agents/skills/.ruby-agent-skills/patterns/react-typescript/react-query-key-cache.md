---
name: react-query-key-cache
description: Make cache identity reflect the complete resource identity.
family: react-typescript
---

# React Query Key Cache

## Problem
A client-side cache stores parameterized or user-scoped resources.

## Use when
The data is not cached or identity is inherently singleton.

## Do not use when
Do not activate simply when The data is not cached or identity is inherently singleton. 

## Repository inspection
Inspect query parameters, tenant/account context, sorting, filters, and freshness rules.

## Implementation procedure
Build stable keys from every dimension that changes the resource and centralize key construction.

## Example

```ts
// Keys contain every dimension that changes the response, so two tenants or
// two filters never share a cache entry.
export const invoiceKeys = {
  all: (tenantId: string) => ["tenant", tenantId, "invoices"] as const,
  list: (tenantId: string, filters: { status: "open" | "paid"; page: number }) =>
    [...invoiceKeys.all(tenantId), "list", filters.status, filters.page] as const,
  detail: (tenantId: string, invoiceId: string) => [...invoiceKeys.all(tenantId), "detail", invoiceId] as const
};

// After a mutation, invalidate by prefix: every list and detail for that tenant.
export function keysToInvalidate(tenantId: string) {
  return invoiceKeys.all(tenantId);
}
```

## Failure modes
One broad key for many resources, including mutable presentation state accidentally.

## Testing
Test distinct identities, cache hits, and invalidation.

## Review checklist
Could two different resources ever share this key?

## Related skills
react-data-fetching
