---
name: react-server-state-boundary
description: Keep remote resource state distinct from local UI state.
family: react-typescript
---

# React Server State Boundary

## Problem
The UI consumes API-backed resources with freshness, loading, and retry semantics.

## Use when
The state is purely local and has no remote lifecycle.

## Do not use when
Do not activate simply when The state is purely local and has no remote lifecycle. 

## Repository inspection
Inspect existing query/cache infrastructure, authentication, and resource identity.

## Implementation procedure
Use repository-standard server-state tooling, define freshness, and expose loading/error/success states deliberately.

## Example

```tsx
import { useEffect, useState } from "react";

// Server state (fetched, may go stale) is kept apart from UI state (which tab
// is open). Only the server-state hook knows about the network.
type Project = { id: string; name: string };

export function useProjects(load: (signal: AbortSignal) => Promise<Project[]>) {
  const [data, setData] = useState<Project[]>();
  const [error, setError] = useState<string>();
  useEffect(() => {
    const controller = new AbortController();
    load(controller.signal)
      .then(setData)
      .catch((reason: unknown) => { if (!controller.signal.aborted) setError(String(reason)); });
    return () => controller.abort();
  }, [load]);
  return { data, error };
}

export function ProjectsPage({ load }: { load: (signal: AbortSignal) => Promise<Project[]> }) {
  const { data, error } = useProjects(load);
  const [tab, setTab] = useState<"active" | "archived">("active"); // UI state only
  if (error) return <p role="alert">{error}</p>;
  if (!data) return <p role="status">Loading…</p>;
  return (
    <div>
      <button type="button" onClick={() => setTab(tab === "active" ? "archived" : "active")}>{tab}</button>
      <ul>{data.map((project) => <li key={project.id}>{project.name}</li>)}</ul>
    </div>
  );
}
```

## Failure modes
Putting server state in UI context, duplicate fetch logic, and stale data treated as current truth.

## Testing
Test cache hit, refetch, failure, invalidation, and auth context.

## Review checklist
Where is server-state ownership defined?

## Related skills
react-data-fetching,react-architecture
