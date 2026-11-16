---
name: react-memoization-evidence-gate
description: Add memoization only when stable identity and measured workload make the trade-off explicit.
family: react-typescript
---

# React Memoization Evidence Gate

## Problem
A render hotspot is caused by repeated expensive work or unnecessary child renders.

## Use when
The component is small, cheap, or the inputs change on nearly every render.

## Do not use when
Do not activate simply because the UI contains JavaScript or because an abstraction is available.

## Repository inspection
Inspect render frequency, prop identity, calculation cost, and profiler evidence.

## Implementation procedure
Fix state ownership first, then memoize the narrowest proven boundary and verify memory and complexity trade-offs.

## Example

```tsx
import { memo, useMemo } from "react";

type Row = { id: string; values: readonly number[] };

// Added after the React Profiler showed SummaryTable re-rendering on every
// keystroke of an unrelated input and computeStats taking ~40 ms per render.
// Without that evidence, neither memo nor useMemo would be here.
function computeStats(rows: readonly Row[]) {
  return rows.map((row) => ({ id: row.id, max: Math.max(...row.values) }));
}

export const SummaryTable = memo(function SummaryTable({ rows }: { rows: readonly Row[] }) {
  const stats = useMemo(() => computeStats(rows), [rows]);
  return <ul>{stats.map((stat) => <li key={stat.id}>{stat.max}</li>)}</ul>;
});
```

## Failure modes
Blanket memoization, memoizing cheap primitive work, and cargo-cult optimization.

## Testing
Compare measured render cost before and after.

## Review checklist
What concrete render cost or identity churn does memoization remove?

## Related skills
react-accessibility-performance,react-state-effects
