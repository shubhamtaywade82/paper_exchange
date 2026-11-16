---
name: react-network-mock-boundary
description: Mock network behavior at the HTTP boundary when isolating UI integration.
family: react-typescript
---

# React Network Mock Boundary

## Problem
A component depends on remote data and the test should remain independent of real services.

## Use when
The test is specifically validating the network client implementation itself.

## Do not use when
Do not activate simply when The test is specifically validating the network client implementation itself. 

## Repository inspection
Inspect existing request mocks, fixtures, and request identity.

## Implementation procedure
Mock stable request/response behavior including failures and delays without mocking React internals.

## Example

```tsx
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, test, vi } from "vitest";
import { useEffect, useState } from "react";

function Balance({ load }: { load: () => Promise<number> }) {
  const [cents, setCents] = useState<number>();
  useEffect(() => { load().then(setCents).catch(() => setCents(-1)); }, [load]);
  if (cents === undefined) return <p role="status">Loading…</p>;
  return cents < 0 ? <p role="alert">Unavailable</p> : <p>Balance {(cents / 100).toFixed(2)}</p>;
}

afterEach(cleanup);

// Fake the network at the boundary the component depends on, never a real service.
test("renders the loaded balance", async () => {
  render(<Balance load={vi.fn().mockResolvedValue(12_50)} />);
  expect(await screen.findByText("Balance 12.50")).toBeTruthy();
});

test("renders the failure state", async () => {
  render(<Balance load={vi.fn().mockRejectedValue(new Error("503"))} />);
  expect(await screen.findByRole("alert")).toBeTruthy();
});
```

## Failure modes
Mocking every child, hard-coded fetch spies scattered across tests, and leaking fixture state.

## Testing
Test success, error, cancellation, and relevant response variants.

## Review checklist
Is the mock preserving the contract shape consumers actually receive?

## Related skills
react-testing-engineering,react-data-fetching
