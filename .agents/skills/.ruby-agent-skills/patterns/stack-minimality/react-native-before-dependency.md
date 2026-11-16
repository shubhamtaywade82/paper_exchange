---
name: react-native-before-dependency
description: React Native Before Dependency
family: stack-minimality
---
# React Native Before Dependency

## Problem
A package adds bundle, supply-chain, upgrade, and API-surface cost when the platform already solves a narrow need.

## Use when
Considering an npm package for a small browser or UI behavior.

## Do not use when
The capability is materially complex, security-sensitive, accessibility-sensitive, unsupported by target browsers, or already handled by an established package.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Check package manifests, browser support, and native browser, CSS, React, and TypeScript capabilities before adding a package.

## Example

```tsx
// Before: a date-formatting package and a clipboard package for two call sites.
// After: the platform already covers both.
export function Receipt({ paidAt, reference }: { paidAt: Date; reference: string }) {
  const paid = new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(paidAt);
  return (
    <p>
      Paid {paid}{" "}
      <button type="button" onClick={() => void navigator.clipboard.writeText(reference)}>
        Copy reference
      </button>
    </p>
  );
}
```

## Failure modes
Package-per-primitive and duplicate utility libraries.

## Testing
Verify supported-browser behavior and frontend build/test checks.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
react-component-engineering, react-accessibility-performance, typescript-core-engineering, stack-minimality
