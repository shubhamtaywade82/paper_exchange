---
name: active-record-deletion-contract
description: Use when changing destroy/delete/dependent behavior or any deletion that crosses callbacks, associations, storage, or auditing.
family: rails
---

# Active Record Deletion Contract

## Problem

Deleting a row and destroying an Active Record object have different lifecycle and dependency semantics.

## Use when

- changing destroy/delete behavior
- changing dependent options
- adding bulk deletion
- debugging orphaned records.

## Do not use when

- no deletion semantics change.

## Repository inspection

Inspect associations, dependent options, callbacks, database cascades, audit/event behavior, storage cleanup, and authorization.

## Implementation procedure

1. Define the required business outcome.
2. Map application and database deletion behavior.
3. Identify callbacks and dependent cleanup.
4. Choose destroy/delete/bulk operation deliberately.
5. Add regression tests for dependents and side effects.

## Example

```ruby
class Account < ApplicationRecord
  # destroy runs callbacks and dependents; the database foreign keys agree:
  #   add_foreign_key :projects, :accounts, on_delete: :restrict
  has_many :projects, dependent: :destroy
  has_many :audit_events, dependent: :restrict_with_exception
end

account.destroy!                          # per-record lifecycle, dependents, callbacks
Session.where(expires_at: ...1.day.ago).delete_all # deliberate: no callbacks, one SQL DELETE
```

## Failure modes

- deleting without authorization
- assuming database cascade invokes model callbacks
- creating orphaned storage or audit records
- switching to delete for unmeasured performance.

## Testing

Test parent deletion, dependent behavior, authorization, cleanup, and bulk semantics.

## Review checklist

- [ ] deletion is authorized
- [ ] application and DB cascades are understood
- [ ] cleanup is explicit
- [ ] irreversible effects are tested

## Related skills

rails-active-record, rails-associations, rails-active-storage, rails-security, rails-database-engineering
