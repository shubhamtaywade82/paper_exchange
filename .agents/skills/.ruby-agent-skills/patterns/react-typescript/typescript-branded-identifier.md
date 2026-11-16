---
name: typescript-branded-identifier
description: Prevent accidental mixing of structurally identical identifiers at important boundaries.
family: react-typescript
---

# Typescript Branded Identifier

## Problem
Different domains use the same primitive representation, such as user and account IDs.

## Use when
The distinction has no material correctness value or the repository already has a stronger identifier abstraction.

## Do not use when
Do not activate simply when The distinction has no material correctness value or the repository already has a stronger identifier abstraction. 

## Repository inspection
Inspect existing domain identifiers and serialization boundaries.

## Implementation procedure
Create a lightweight brand at the domain boundary and remove it only at explicit serialization or persistence boundaries.

## Example

```ts
declare const tag: unique symbol;
type Id<T extends string> = string & { readonly [tag]: T };

export type UserId = Id<"User">;
export type AccountId = Id<"Account">;

// Brands are applied once, at the boundary where the value is known to be valid.
export const toUserId = (raw: string): UserId => raw as UserId;
export const toAccountId = (raw: string): AccountId => raw as AccountId;

export function addMember(account: AccountId, user: UserId): string {
  return `${account}:${user}`;
}

const account = toAccountId("acct_1");
const user = toUserId("usr_9");
addMember(account, user);
// addMember(user, account); // error: UserId is not assignable to AccountId
```

## Failure modes
Branding every primitive, unsafe casting, and leaking internal brands into transport payloads.

## Testing
Compile-time mixing checks and runtime serialization tests.

## Review checklist
Does the brand protect a real invariant without spreading needless complexity?

## Related skills
typescript-type-design
