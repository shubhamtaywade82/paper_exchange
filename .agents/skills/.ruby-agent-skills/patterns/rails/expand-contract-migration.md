---
name: expand-contract-migration
description: Safely evolve a production schema across rolling application deployments.
family: rails
---

# Expand-Contract Migration

## Problem
Old and new application versions can overlap during deployment, so a schema change must remain compatible throughout the transition.

## Use when
A production schema change removes or renames data, changes nullability or type, or requires dual-read/dual-write behavior.

## Do not use when
The database change is provably atomic and compatible with every application version that can run during deployment.

## Implementation procedure
1. Identify old and new application versions that may overlap.
2. Expand the schema without breaking old code.
3. Deploy code that can use both states.
4. Backfill and validate.
5. Switch reads/writes to the new representation.
6. Remove old compatibility code.
7. Contract the schema in a later migration.

## Example

```ruby
# Release 1 (expand): add nullable column; code writes both columns.
class AddEmailAddressToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_address, :string
  end
end

# Release 1 (backfill, bounded and rerunnable):
class BackfillUserEmailAddress < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    User.unscoped.where(email_address: nil).in_batches(of: 5_000) do |batch|
      batch.update_all("email_address = email")
    end
  end

  def down = nil
end

# Release 2 (cutover): code reads email_address only; ignore the old column.
class User < ApplicationRecord
  self.ignored_columns += ["email"]
end

# Release 3 (contract): remove it once no running version references it.
class RemoveEmailFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email, :string
  end
end
```

## Failure modes
- removing a column before all old processes stop reading it
- making a new column non-null before backfill
- changing semantics without compatibility
- combining expansion and destructive cleanup

## Testing
Test intermediate schema/application states where practical and verify deployment order.

## Review checklist
- rollout compatibility documented
- backfill completion criterion exists
- cutover is explicit
- destructive cleanup is separated

## Repository inspection

Inspect the repository's runtime/version, existing conventions, neighboring tests or implementation patterns, and the actual owning boundary before applying this pattern.

## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
