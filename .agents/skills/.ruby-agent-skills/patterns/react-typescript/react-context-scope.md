---
name: react-context-scope
description: Limit context to genuinely shared cross-cutting state.
family: react-typescript
---

# React Context Scope

## Problem
Many distant descendants need the same stable dependency and prop flow is materially noisy.

## Use when
Only one or two nearby layers need the value.

## Do not use when
Do not activate simply when Only one or two nearby layers need the value. 

## Repository inspection
Inspect provider nesting, update frequency, and consumer count.

## Implementation procedure
Scope the provider narrowly, keep the value stable where useful, and preserve explicit ownership.

## Example

```tsx
import { createContext, useContext, useMemo, type ReactNode } from "react";

// Context for a stable dependency many distant descendants need, provided at
// the smallest subtree that needs it, with a stable value.
type Formatter = { money: (cents: number) => string };
const FormatterContext = createContext<Formatter | null>(null);

export function FormatterProvider({ locale, currency, children }: { locale: string; currency: string; children: ReactNode }) {
  const value = useMemo<Formatter>(() => {
    const format = new Intl.NumberFormat(locale, { style: "currency", currency });
    return { money: (cents) => format.format(cents / 100) };
  }, [locale, currency]);
  return <FormatterContext.Provider value={value}>{children}</FormatterContext.Provider>;
}

export function useFormatter(): Formatter {
  const formatter = useContext(FormatterContext);
  if (!formatter) throw new Error("useFormatter must be used inside FormatterProvider");
  return formatter;
}
```

## Failure modes
Global context for server data, mutable event buses, and giant all-purpose providers.

## Testing
Test provider absence, default behavior, updates, and isolation between providers.

## Review checklist
Does context solve reachability rather than conceal architecture?

## Related skills
react-state-effects,react-architecture
