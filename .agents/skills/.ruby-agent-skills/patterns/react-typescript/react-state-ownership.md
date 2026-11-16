---
name: react-state-ownership
description: Place state at the narrowest owner that needs to coordinate the behavior.
family: react-typescript
---

# React State Ownership

## Problem
State is duplicated, lifted too far, or passed through unrelated layers.

## Use when
A repository-wide state contract genuinely requires broader scope.

## Do not use when
Do not activate simply when A repository-wide state contract genuinely requires broader scope. 

## Repository inspection
Inspect consumers, mutation sources, derived values, and provider boundaries.

## Implementation procedure
Keep local state local, lift only to the nearest meaningful owner, and derive values instead of duplicating them.

## Example

```tsx
import { useState } from "react";

// State lives at the closest common owner of the two components that use it,
// not at the app root and not duplicated in each child.
function Filter({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return <input aria-label="Filter" value={value} onChange={(event) => onChange(event.target.value)} />;
}

function Results({ items, filter }: { items: readonly string[]; filter: string }) {
  return <ul>{items.filter((item) => item.includes(filter)).map((item) => <li key={item}>{item}</li>)}</ul>;
}

export function SearchPanel({ items }: { items: readonly string[] }) {
  const [filter, setFilter] = useState("");
  return (
    <>
      <Filter value={filter} onChange={setFilter} />
      <Results items={items} filter={filter} />
    </>
  );
}
```

## Failure modes
Global state by default, duplicated mirrors, and context used for ordinary prop flow.

## Testing
Test transitions from each relevant event and verify derived values stay consistent.

## Review checklist
Can the state owner be named in one sentence?

## Related skills
react-state-effects,react-architecture
