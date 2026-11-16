---
name: react-reducer-state-machine
description: Use a reducer when UI transitions form a meaningful state machine.
family: react-typescript
---

# React Reducer State Machine

## Problem
Many related events update coupled state or the valid transitions are easier to express as actions.

## Use when
State is trivial and one or two local transitions are easier with useState.

## Do not use when
Do not activate simply when State is trivial and one or two local transitions are easier with useState. 

## Repository inspection
Inspect transition count, invalid transitions, and action ownership.

## Implementation procedure
Define explicit actions and a reducer that preserves valid states; keep side effects outside the reducer.

## Example

```tsx
import { useReducer } from "react";

type State =
  | { step: "editing"; draft: string }
  | { step: "submitting"; draft: string }
  | { step: "failed"; draft: string; message: string }
  | { step: "done" };

type Action =
  | { type: "edit"; draft: string }
  | { type: "submit" }
  | { type: "failed"; message: string }
  | { type: "succeeded" };

// Only listed transitions are possible; anything else leaves state unchanged.
export function reducer(state: State, action: Action): State {
  switch (state.step) {
    case "editing":
      if (action.type === "edit") return { step: "editing", draft: action.draft };
      if (action.type === "submit") return { step: "submitting", draft: state.draft };
      return state;
    case "submitting":
      if (action.type === "failed") return { step: "failed", draft: state.draft, message: action.message };
      if (action.type === "succeeded") return { step: "done" };
      return state;
    case "failed":
      if (action.type === "edit") return { step: "editing", draft: action.draft };
      if (action.type === "submit") return { step: "submitting", draft: state.draft };
      return state;
    case "done":
      return state;
  }
}

export function useCommentForm() {
  return useReducer(reducer, { step: "editing", draft: "" });
}
```

## Failure modes
Reducers used as generic state containers, hidden side effects, and arbitrary string actions.

## Testing
Test action-to-state transitions and invalid actions.

## Review checklist
Are transitions easier to reason about as named events?

## Related skills
react-state-effects,typescript-type-design
