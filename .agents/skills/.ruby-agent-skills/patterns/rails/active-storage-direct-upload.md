---
name: active-storage-direct-upload
description: Design Rails Active Storage direct uploads as an explicit browser-to-storage lifecycle with authorization, CORS, and orphan cleanup.
family: rails
---

# Active Storage Direct Upload

## Problem

Direct uploads reduce application-server bandwidth but introduce a staged object lifecycle outside the database transaction.

## Use when

- enabling browser direct uploads;
- changing upload JavaScript or storage CORS;
- diagnosing unattached blobs.

## Do not use when

- uploads intentionally pass through the application server.

## Repository inspection

Inspect storage service, direct upload endpoint, CORS, client events, signed blob IDs, attachment flow, cleanup schedule, and tests.

## Implementation procedure

1. Define the authorized upload target.
2. Configure the isolated storage service.
3. Restrict CORS.
4. Complete browser upload.
5. Attach only through an authorized domain boundary.
6. Measure/monitor unattached blobs.
7. Schedule bounded cleanup.
8. Test interruption and retry behavior.

## Example

```ruby
# 1. The browser uploads to storage and receives a signed blob id.
# 2. The form submits that id; the server attaches it only to a record the
#    user may edit.
# 3. Blobs never attached are cleaned up by a scheduled job.
class DocumentsController < ApplicationController
  def create
    document = current_account.documents.build(title: params.expect(document: [:title])[:title])
    document.file.attach(params.expect(document: [:file])[:file]) # signed_id from the direct upload
    document.save!
    redirect_to document
  end
end

class PurgeUnattachedBlobsJob < ApplicationJob
  def perform
    ActiveStorage::Blob.unattached.where(created_at: ...2.days.ago).find_each(&:purge_later)
  end
end
```

## Failure modes

- treating signed ID as authorization;
- CORS open to arbitrary origins;
- orphan accumulation;
- assuming upload and domain commit are atomic;
- retrying uploads without understanding duplicate object lifecycle.

## Testing

Test successful upload/attach, failed attach, cross-tenant attach, CORS contract where practical, and orphan cleanup.

## Review checklist

- [ ] authorized target
- [ ] CORS restricted
- [ ] staged lifecycle understood
- [ ] cleanup bounded
- [ ] interruption tested

## Related skills

rails-active-storage, rails-api-integration, rails-security, rails-active-job
