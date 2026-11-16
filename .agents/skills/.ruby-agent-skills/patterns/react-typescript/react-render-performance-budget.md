---
name: react-render-performance-budget
description: Use evidence to define a rendering performance boundary before optimizing.
family: react-typescript
---

# React Render Performance Budget

## Problem
A component tree exhibits measurable latency, excess renders, or expensive list rendering.

## Use when
No workload evidence shows a performance problem.

## Do not use when
Do not activate simply because the UI contains JavaScript or because an abstraction is available.

## Repository inspection
Inspect profiler traces, list sizes, state ownership, and stable identities.

## Implementation procedure
Identify the hot path, set a measurable budget, and fix ownership or identity issues before adding optimization.

## Example

```tsx
import { Profiler, type ProfilerOnRenderCallback, type ReactNode } from "react";

// Budget: the orders table must render in under 16 ms at 500 rows. The
// Profiler reports actual render durations so regressions are measurable.
const BUDGET_MS = 16;

const report: ProfilerOnRenderCallback = (id, phase, actualDuration) => {
  if (actualDuration > BUDGET_MS) {
    console.warn(`${id} ${phase} render took ${actualDuration.toFixed(1)} ms (budget ${BUDGET_MS} ms)`);
  }
};

export function Measured({ children }: { children: ReactNode }) {
  return <Profiler id="OrdersTable" onRender={report}>{children}</Profiler>;
}
```

## Failure modes
Premature memoization, arbitrary thresholds, and performance claims from intuition.

## Testing
Use profiler or benchmark evidence plus regression checks where practical.

## Review checklist
What measured workload justifies the optimization?

## Related skills
react-accessibility-performance,react-architecture
