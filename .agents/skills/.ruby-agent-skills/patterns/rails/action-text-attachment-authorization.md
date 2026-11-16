---
name: action-text-attachment-authorization
description: Authorize Action Text embedded Active Storage attachments and Signed Global ID attachables against the owning resource and tenant.
family: rails
---

# Action Text Attachment Authorization

## Problem

Sanitized rich text can still expose private application objects or files through embedded attachments that the viewer is not authorized to see.

## Use when

- embedding Active Storage files;
- allowing arbitrary attachables;
- rendering private rich text.

## Do not use when

- rich text has no private attachments or attachable objects.

## Repository inspection

Inspect owner authorization, tenant scope, attachable classes, SGID verification, Active Storage access, and custom partials.

## Implementation procedure

1. Authorize editor/reference creation.
2. Limit attachable object types.
3. Verify tenant/resource scope.
4. Review SGID semantics.
5. Authorize rendering/access to embedded resources.
6. Test cross-tenant/private cases.

## Example

```ruby
# Direct uploads are tagged with the uploader's account...
class DirectUploadsController < ActiveStorage::DirectUploadsController
  before_action :require_login

  private

  def blob_args
    args = super
    args.merge(metadata: (args[:metadata] || {}).merge("account_id" => Current.account.id))
  end
end

# ...so an embedded blob from another account (e.g. a pasted Signed Global
# ID) is rejected before the article saves.
class Article < ApplicationRecord
  has_rich_text :body
  belongs_to :account

  validate :embedded_blobs_belong_to_account

  private

  def embedded_blobs_belong_to_account
    blobs = body.body&.attachables.to_a.grep(ActiveStorage::Blob)
    foreign = blobs.reject { |blob| blob.metadata["account_id"] == account_id }
    errors.add(:body, :invalid_attachment) if foreign.any?
  end
end
```

## Failure modes

- SGID treated as authorization;
- arbitrary object embedding;
- private blob rendered to unauthorized viewer;
- attachable partial exposes sensitive fields.

## Testing

Test authorized/unauthorized editors and viewers, cross-tenant references, deleted attachables, and private attachments.

## Review checklist

- [ ] allowed attachables
- [ ] reference authorization
- [ ] tenant scope
- [ ] viewer access
- [ ] partial safety
- [ ] negative tests

## Related skills

rails-action-text, rails-active-storage, rails-security, rails-security-engineering
