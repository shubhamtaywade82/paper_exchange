---
name: react-controlled-input
description: Make form control ownership explicit.
family: react-typescript
---

# React Controlled Input

## Problem
A form field must be controlled by application state or intentionally owned by the DOM.

## Use when
The repository already defines a compatible form abstraction and the change would only duplicate it.

## Do not use when
Do not activate simply when The repository already defines a compatible form abstraction and the change would only duplicate it. 

## Repository inspection
Inspect validation, form library, reset behavior, and submission ownership.

## Implementation procedure
Choose one owner, define value/change semantics, and document reset/error behavior.

## Example

```tsx
import { useState } from "react";

// Controlled: the value lives in state because the UI reacts to every change.
export function UsernameField({ taken }: { taken: (name: string) => boolean }) {
  const [name, setName] = useState("");
  const unavailable = name !== "" && taken(name);
  return (
    <label>
      Username
      <input value={name} onChange={(event) => setName(event.target.value.trim())} aria-invalid={unavailable} />
      {unavailable && <span role="alert">That username is taken</span>}
    </label>
  );
}

// Uncontrolled: the DOM owns the value; read it once on submit.
export function NoteForm({ onSave }: { onSave: (note: string) => void }) {
  return (
    <form onSubmit={(event) => { event.preventDefault(); onSave(String(new FormData(event.currentTarget).get("note") ?? "")); }}>
      <textarea name="note" defaultValue="" />
      <button type="submit">Save</button>
    </form>
  );
}
```

## Failure modes
Mixing controlled and uncontrolled modes, defaultValue plus value confusion, and hidden state synchronization.

## Testing
Test typing, reset, validation, submit, and rerender behavior.

## Review checklist
Who owns the source of truth at every transition?

## Related skills
react-component-engineering,react-state-effects
