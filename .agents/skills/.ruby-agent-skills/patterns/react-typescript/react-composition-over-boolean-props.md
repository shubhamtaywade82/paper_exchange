---
name: react-composition-over-boolean-props
description: Use composition to express structural variation instead of growing a boolean prop matrix.
family: react-typescript
---

# React Composition Over Boolean Props

## Problem
A component is accumulating flags that alter large portions of structure.

## Use when
A flag controls one small stable visual variation and remains readable.

## Do not use when
Do not activate simply when A flag controls one small stable visual variation and remains readable. 

## Repository inspection
Inspect all prop combinations and conditional branches.

## Implementation procedure
Replace structurally distinct variants with children, slots, or small composed components.

## Example

```tsx
import type { ReactNode } from "react";

// Before: <Alert isError hasIcon isDismissible showRetry ... />
// After: the caller composes the parts it needs.
export function Alert({ tone, children }: { tone: "info" | "error"; children: ReactNode }) {
  return <div role={tone === "error" ? "alert" : "status"}>{children}</div>;
}

export function AlertActions({ children }: { children: ReactNode }) {
  return <div>{children}</div>;
}

export function SaveFailed({ onRetry }: { onRetry: () => void }) {
  return (
    <Alert tone="error">
      Could not save.
      <AlertActions>
        <button type="button" onClick={onRetry}>Retry</button>
      </AlertActions>
    </Alert>
  );
}
```

## Failure modes
Impossible flag combinations and deeply nested ternaries.

## Testing
Test each composed variant and shared behavior.

## Review checklist
Can invalid combinations disappear from the API?

## Related skills
react-component-engineering
