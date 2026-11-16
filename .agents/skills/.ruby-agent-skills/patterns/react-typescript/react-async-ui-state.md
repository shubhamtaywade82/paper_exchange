---
name: react-async-ui-state
description: Model loading, refreshing, empty, error, and success states separately where the distinction is user-visible.
family: react-typescript
---

# React Async Ui State

## Problem
Remote or deferred work produces multiple UI states that have different actions or messaging.

## Use when
A simple synchronous component has no asynchronous lifecycle.

## Do not use when
Do not activate simply when A simple synchronous component has no asynchronous lifecycle. 

## Repository inspection
Inspect resource lifecycle, retry controls, and accessibility announcements.

## Implementation procedure
Define explicit state transitions and preserve prior useful data during refresh when appropriate.

## Example

```tsx
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "error"; message: string; retry: () => void }
  | { status: "success"; data: T };

// Each state has its own message and available actions; no boolean soup.
export function InvoiceList({ state }: { state: AsyncState<readonly { id: string }[]> }) {
  switch (state.status) {
    case "idle":
      return null;
    case "loading":
      return <p role="status">Loading invoices…</p>;
    case "error":
      return (
        <div role="alert">
          {state.message} <button type="button" onClick={state.retry}>Try again</button>
        </div>
      );
    case "success":
      return state.data.length === 0 ? (
        <p>No invoices yet.</p>
      ) : (
        <ul>{state.data.map((invoice) => <li key={invoice.id}>{invoice.id}</li>)}</ul>
      );
  }
}
```

## Failure modes
One isLoading boolean, hidden errors, and empty state confused with failure.

## Testing
Test each state and transitions between them.

## Review checklist
Can the UI explain both no data and failed data retrieval?

## Related skills
react-data-fetching,react-component-engineering
