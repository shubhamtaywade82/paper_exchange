---
name: react-component-boundary
description: Give a component one coherent user-visible responsibility.
family: react-typescript
---

# React Component Boundary

## Problem
Creating or refactoring a component with mixed concerns.

## Use when
The component is already a small cohesive leaf and extraction would only add indirection.

## Do not use when
Do not activate simply when The component is already a small cohesive leaf and extraction would only add indirection. 

## Repository inspection
Inspect parent/child responsibilities, shared UI primitives, data ownership, and tests.

## Implementation procedure
Separate presentation, state, and integration responsibilities while keeping the public prop contract minimal.

## Example

```tsx
// Split by responsibility: the container fetches and decides, the view renders.
type Profile = { name: string; email: string };

export function ProfileView({ profile, onEdit }: { profile: Profile; onEdit: () => void }) {
  return (
    <section>
      <h2>{profile.name}</h2>
      <p>{profile.email}</p>
      <button type="button" onClick={onEdit}>Edit</button>
    </section>
  );
}

export function ProfileContainer({ profile, navigate }: { profile: Profile | undefined; navigate: (path: string) => void }) {
  if (!profile) return <p role="status">Loading…</p>;
  return <ProfileView profile={profile} onEdit={() => navigate("/profile/edit")} />;
}
```

## Failure modes
God components, hidden side effects, and extraction that creates a meaningless wrapper.

## Testing
Test observable rendering and interaction at the owning boundary.

## Review checklist
Is the boundary justified by responsibility rather than line count?

## Related skills
react-component-engineering,react-architecture
