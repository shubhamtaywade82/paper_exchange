---
name: active-storage-boundary
description: Define the ownership, cardinality, lifecycle, and access contract for a Rails Active Storage attachment.
family: rails
---

# Active Storage Boundary

## Problem

An attachment becomes fragile when ownership, storage, and deletion semantics are implicit across models, controllers, jobs, and storage providers.

## Use when

- adding or changing Active Storage attachments;
- deciding one-to-one versus collection semantics;
- changing replacement/deletion behavior.

## Do not use when

- the feature does not use Active Storage.

## Repository inspection

Inspect attachment declarations, domain ownership, tenant rules, validations, storage services, routes, purge jobs, and tests.

## Implementation procedure

1. Identify the domain owner.
2. Define cardinality.
3. Define allowed file contract.
4. Define replacement/additive semantics.
5. Define access authorization.
6. Define retention and purge behavior.
7. Define processing/variant behavior.
8. Test the lifecycle.

## Example

```ruby
class Contract < ApplicationRecord
  belongs_to :account

  # One owned file; replacing it detaches the old one and purges it later.
  has_one_attached :signed_pdf do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 200], preprocessed: true
  end

  validate :signed_pdf_is_a_pdf

  private

  def signed_pdf_is_a_pdf
    return unless signed_pdf.attached?

    errors.add(:signed_pdf, :content_type) unless signed_pdf.content_type == "application/pdf"
    errors.add(:signed_pdf, :too_large) if signed_pdf.byte_size > 20.megabytes
  end
end
```

## Failure modes

- blob lookup used as authorization;
- ambiguous replacement semantics;
- orphaned blobs;
- deletion without retention review;
- attachment state inconsistent with domain state.

## Testing

Test attach, replace/add, access, remove, purge, and authorization behavior.

## Review checklist

- [ ] owner
- [ ] cardinality
- [ ] authorization
- [ ] validation
- [ ] retention
- [ ] purge semantics

## Related skills

rails-active-storage, rails-security, rails-database-engineering, rails-test-engineering
