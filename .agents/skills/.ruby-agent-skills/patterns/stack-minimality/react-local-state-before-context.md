---
name: react-local-state-before-context
description: React Local State Before Context
family: stack-minimality
---
# React Local State Before Context

## Problem
Global providers increase coupling and rerender scope when state is local to one feature or subtree.

## Use when
Choosing local state, props, context, or external state.

## Do not use when
Multiple legitimate consumers require a shared owner.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Trace state readers and writers and provider boundaries. Keep state at the smallest common owner.

## Example

```tsx
import { useState } from "react";

// Before: a FilterContext provider at the app root for one table's filter.
// After: the filter lives with the only subtree that uses it.
export function OrdersScreen({ orders }: { orders: readonly { id: string; status: string }[] }) {
  const [status, setStatus] = useState("all");
  const visible = status === "all" ? orders : orders.filter((order) => order.status === status);
  return (
    <>
      <label>
        Status
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="all">All</option>
          <option value="open">Open</option>
          <option value="paid">Paid</option>
        </select>
      </label>
      <ul>
        {visible.map((order) => (
          <li key={order.id}>{order.id}</li>
        ))}
      </ul>
    </>
  );
}
```

## Failure modes
Global-by-default state, provider nesting, and hidden dependencies.

## Testing
Test user behavior and state ownership effects at the feature boundary.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
react-state-effects, react-architecture, react-testing-engineering, stack-minimality
