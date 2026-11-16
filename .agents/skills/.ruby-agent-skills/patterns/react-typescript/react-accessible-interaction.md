---
name: react-accessible-interaction
description: Prefer native semantics and explicit accessible names for interactive controls.
family: react-typescript
---

# React Accessible Interaction

## Problem
Creating buttons, dialogs, menus, forms, tabs, or custom interactions.

## Use when
A platform-native semantic element already provides the needed contract.

## Do not use when
Do not activate simply because the UI contains JavaScript or because an abstraction is available.

## Repository inspection
Inspect existing design-system primitives and keyboard behavior.

## Implementation procedure
Use semantic elements first, define labels or roles only when necessary, and preserve keyboard support.

## Example

```tsx
import { useId, useState } from "react";

// A disclosure built on a real <button>: keyboard, focus, and screen-reader
// semantics come from the element; aria-expanded/aria-controls describe state.
export function Disclosure({ summary, children }: { summary: string; children: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const panelId = useId();
  return (
    <div>
      <button type="button" aria-expanded={open} aria-controls={panelId} onClick={() => setOpen((value) => !value)}>
        {summary}
      </button>
      <div id={panelId} hidden={!open}>
        {children}
      </div>
    </div>
  );
}
```

## Failure modes
Clickable divs, placeholder-only labels, inaccessible custom widgets, and visual-only state.

## Testing
Test role/name queries, keyboard interaction, focus, and announced state.

## Review checklist
Can a keyboard and assistive technology user discover and operate it?

## Related skills
react-accessibility-performance,react-component-engineering
