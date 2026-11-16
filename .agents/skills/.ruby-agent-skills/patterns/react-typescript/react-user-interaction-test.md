---
name: react-user-interaction-test
description: Test what the user can observe and do instead of component implementation details.
family: react-typescript
---

# React User Interaction Test

## Problem
Adding regression coverage for React UI behavior.

## Use when
A lower-level pure function has a simpler deterministic contract.

## Do not use when
Do not activate simply when A lower-level pure function has a simpler deterministic contract. 

## Repository inspection
Inspect accessibility roles, user events, and external boundaries.

## Implementation procedure
Render at the smallest useful boundary, perform realistic interaction, and assert visible outcomes.

## Example

```tsx
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, test } from "vitest";
import { useState } from "react";

function Counter() {
  const [count, setCount] = useState(0);
  return (
    <>
      <p>Count: {count}</p>
      <button type="button" onClick={() => setCount((value) => value + 1)}>Increment</button>
    </>
  );
}

afterEach(cleanup);

// Query by role and visible text, act through user-event, assert what the user sees.
test("increments when the user clicks the button", async () => {
  render(<Counter />);
  await userEvent.click(screen.getByRole("button", { name: "Increment" }));
  expect(screen.getByText("Count: 1")).toBeTruthy();
});
```

## Failure modes
Private-state assertions, CSS-selector coupling, and arbitrary sleeps.

## Testing
Test success, rejection, and recovery paths using deterministic synchronization.

## Review checklist
Would the test survive a component refactor that preserves behavior?

## Related skills
react-testing-engineering
