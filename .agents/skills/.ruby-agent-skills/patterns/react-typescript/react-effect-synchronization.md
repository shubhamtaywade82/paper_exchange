---
name: react-effect-synchronization
description: Use an effect only to synchronize React with an external system.
family: react-typescript
---

# React Effect Synchronization

## Problem
A component interacts with subscriptions, timers, imperative APIs, or external mutable systems.

## Use when
The logic is a pure calculation or event-driven state transition.

## Do not use when
Do not activate simply when The logic is a pure calculation or event-driven state transition. 

## Repository inspection
Inspect dependencies, cleanup, external resource ownership, and async races.

## Implementation procedure
Define setup, dependency identity, cleanup, and stale-work handling explicitly.

## Example

```tsx
import { useEffect, useState } from "react";

// Subscribe on mount / id change, unsubscribe in cleanup: no leaked listeners
// and no updates from a stale subscription.
type Channel = { subscribe(id: string, onMessage: (count: number) => void): () => void };

export function useUnreadCount(channel: Channel, conversationId: string): number {
  const [count, setCount] = useState(0);
  useEffect(() => {
    setCount(0);
    const unsubscribe = channel.subscribe(conversationId, setCount);
    return unsubscribe;
  }, [channel, conversationId]);
  return count;
}
```

## Failure modes
Effects that derive state, missing cleanup, disabled dependency lint, and effect chains.

## Testing
Test mount/unmount, reruns, cleanup, and stale asynchronous completion.

## Review checklist
What external system is this effect synchronizing?

## Related skills
react-state-effects
