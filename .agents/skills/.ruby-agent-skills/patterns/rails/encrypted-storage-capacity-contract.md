---
name: encrypted-storage-capacity-contract
description: Encrypted Storage Capacity Contract
family: rails
---
# Encrypted Storage Capacity Contract

## Problem
Encryption adds ciphertext metadata and encoding overhead that can overflow columns or invalidate assumptions about storage/indexes.

## Use when
Encrypting or migrating a bounded string column.

## Do not use when
A text/blob column has ample validated capacity and no relevant index contract.

## Repository inspection
Inspect DB type, limits, encoding, indexes, generated ciphertext behavior, and largest legitimate values.

## Implementation procedure
Calculate practical headroom using representative data and choose a column size/type compatible with the encrypted representation.

## Example

```ruby
class WidenEncryptedColumns < ActiveRecord::Migration[8.0]
  def change
    # Ciphertext (base64 + JSON envelope with iv/auth tag) is larger than the
    # plaintext; size columns for the encrypted form.
    change_column :customers, :phone, :string, limit: 510   # was 20
    change_column :patients, :notes, :text                  # was string(255)
  end
end
# Rule of thumb from the Rails guide: string columns need at least ~255 bytes
# of overhead; verify with a real encrypted value in the test suite.
```

## Failure modes
Truncation, validation errors, index limitations, failed migrations, or production-only oversized values.

## Testing
Test boundary values across supported encodings and verify migration/index behavior.

## Review checklist
[ ] size modeled [ ] encoding considered [ ] index reviewed [ ] boundary test

## Related skills
rails-encryption-credentials-engineering, rails-database-engineering