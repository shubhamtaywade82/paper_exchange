---
name: react-focus-management
description: Define focus entry, movement, and recovery as an explicit interaction contract.
family: react-typescript
---

# React Focus Management

## Problem
Dialogs, menus, routed views, dynamic forms, or async UI changes alter focus context.

## Use when
No focus context changes and native browser behavior already satisfies the workflow.

## Do not use when
Do not activate simply because the UI contains JavaScript or because an abstraction is available.

## Repository inspection
Inspect focus utilities, browser navigation, and restoration expectations.

## Implementation procedure
Capture meaningful prior focus, move focus intentionally, and restore it after the interaction ends.

## Example

```tsx
import { useEffect, useRef } from "react";

// Moving focus into a dialog on open and restoring it to the trigger on close.
export function ConfirmDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const returnFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open) {
      returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      dialog.showModal(); // native dialog traps focus and handles Escape
    } else if (dialog.open) {
      dialog.close();
      returnFocusRef.current?.focus();
    }
  }, [open]);

  return (
    <dialog ref={dialogRef} aria-labelledby="confirm-title" onClose={onClose}>
      <h2 id="confirm-title">Delete project?</h2>
      <button type="button" onClick={onClose} autoFocus>Cancel</button>
    </dialog>
  );
}
```

## Failure modes
Focus traps without recovery, stealing focus on every rerender, and inaccessible loading transitions.

## Testing
Test keyboard navigation, focus restoration, escape/cancel behavior, and unmount cases.

## Review checklist
Where should focus be before, during, and after the interaction?

## Related skills
react-accessibility-performance,react-testing-engineering
