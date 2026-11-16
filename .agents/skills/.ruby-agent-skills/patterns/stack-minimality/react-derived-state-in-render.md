---
name: react-derived-state-in-render
description: React Derived State In Render
family: stack-minimality
---
# React Derived State In Render

## Problem
Duplicated state creates synchronization code and stale values.

## Use when
A component stores a value derivable from existing props, state, or query data.

## Do not use when
The value represents independent user input or deliberately persisted state.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Remove redundant state and derive the value during render. Use memoization only when computation cost is measured.

## Example

```tsx
import { useState } from "react";

type Line = { id: string; cents: number };

// Before: const [total, setTotal] = useState(0); useEffect(() => setTotal(sum(lines)), [lines]);
// After: compute during render; there is nothing to keep in sync.
export function Cart({ lines }: { lines: readonly Line[] }) {
  const [couponCents, setCouponCents] = useState(0);
  const totalCents = lines.reduce((sum, line) => sum + line.cents, 0) - couponCents;
  return (
    <div>
      <p>Total: {(totalCents / 100).toFixed(2)}</p>
      <button type="button" onClick={() => setCouponCents(500)}>
        Apply coupon
      </button>
    </div>
  );
}
```

## Failure modes
Effect-driven synchronization, stale derived values, and memoization without evidence.

## Testing
Test rendered output across the inputs that change the derived value.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
react-state-effects, react-accessibility-performance, stack-minimality
