---
name: rails-active-storage
description: "Use when designing, implementing, reviewing, testing, or operating Rails Active Storage attachments, uploads, direct uploads, storage services, file serving, variants, previews, analysis, purge lifecycle, mirrors, or file-access security."
---

# Rails Active Storage Engineering

## Purpose

Treat uploaded files as a durable external-data boundary, not merely as another Active Record attribute.

Active Storage spans:

- database attachment metadata;
- object storage;
- browser-to-storage uploads;
- file serving/downloads;
- authorization and tenant isolation;
- content analysis;
- transformations and previews;
- background processing;
- cleanup/purge;
- storage migration and replication;
- testing.

Core flow:

```text
define file ownership
-> define allowed file contract
-> choose storage service
-> attach/persist relationship
-> authorize upload/access
-> upload/analyze/transform
-> serve safely
-> observe failures
-> purge/reconcile
```

The Rails Active Storage guide documents attachment macros, storage services, private/public access, direct uploads, analysis, variants/previews, testing, mirrors, and purging unattached uploads. See the source foundation below.

## Activate when

- adding `has_one_attached` or `has_many_attached`;
- changing file upload or attachment flows;
- configuring `config/storage.yml` or environment-specific storage;
- adding S3/GCS/Azure/S3-compatible object storage;
- implementing direct uploads;
- serving or downloading private files;
- adding public file access;
- adding authenticated file controllers;
- adding image/video/PDF variants or previews;
- changing analyzers or content metadata;
- adding file validation;
- implementing attachment cleanup or purge;
- migrating storage providers;
- introducing storage mirrors;
- diagnosing missing, inaccessible, duplicated, orphaned, or slow file operations;
- reviewing upload security or tenant isolation.

Do not activate merely because a model has a normal database attachment URL unrelated to Active Storage. Use the smallest relevant Rails/view/API/security skill when Active Storage is not actually involved.

## Repository inspection

Inspect before changing file behavior:

1. Ruby/Rails version and Active Storage APIs available in that version;
2. existing `has_one_attached` / `has_many_attached` declarations;
3. `config/storage.yml` and environment-specific storage configuration;
4. active storage migrations/schema;
5. object storage provider gems and credentials;
6. direct-upload JavaScript and CORS configuration;
7. routes and Active Storage route configuration;
8. authentication and authorization around file access;
9. tenant/resource ownership rules;
10. upload parameters and strong-parameter conventions;
11. file validations and content-type/size policy;
12. analyzers, variants, previews, and processing jobs;
13. purge jobs or cleanup schedules;
14. CDN/proxy/redirect behavior;
15. logging, metrics, error reporting, and provider telemetry;
16. tests using the Active Storage test service and fixtures;
17. deployment/runtime permissions, buckets, lifecycle policies, and secret configuration.

Do not introduce a second storage abstraction when repository conventions already define one.

## Attachment boundary

Treat the attachment association as a relationship, not the file contents themselves.

The logical model is:

```text
domain record
   |
attachment relationship
   |
ActiveStorage::Blob metadata
   |
object-storage service
   |
actual file bytes
```

Define explicitly:

- owner/resource;
- cardinality;
- replacement versus additive semantics;
- allowed file types;
- maximum size;
- retention;
- access policy;
- transformation policy;
- deletion/purge behavior.

The database relationship is not the authorization policy for the underlying blob.

A valid attachment must still belong to an authorized resource and tenant.

## Active Storage schema ownership

Active Storage uses its own tables for blobs, attachment relationships, and optionally variant records.

Treat these tables as framework-owned persistence infrastructure.

Inspect:

- foreign keys/indexes;
- polymorphic record type behavior;
- primary-key type compatibility;
- variant tracking configuration;
- migration/deployment compatibility.

When domain model class names change, inspect the stored polymorphic type in attachment rows.

Do not hand-edit Active Storage tables as a shortcut for domain changes.

## File contract

A production upload should have an explicit contract:

```text
who can upload
what resource receives it
which file sizes are allowed
which media types are allowed
whether file content needs inspection
whether filenames are user-visible
where it is stored
who can read it
how it is transformed
how long it is retained
how it is deleted
```

Do not treat filename extension or browser-provided content type as sufficient trust.

The storage provider is not the application authorization layer.

## Upload authorization

Before accepting an attachment, verify:

- authenticated actor;
- resource ownership;
- tenant membership;
- action authorization;
- upload purpose;
- allowed attachment slot;
- size/count limits;
- content policy.

For direct uploads, the browser may send bytes directly to storage before the final domain record is persisted. Therefore authorization and attachment ownership must still be enforced when the signed blob is attached to the domain record.

Never interpret possession of a signed blob ID as proof that the caller owns the target resource.

## Tenant isolation

For multi-tenant applications, make resource ownership the authoritative access boundary.

Review:

- attachment lookup by resource;
- blob access through resource routes;
- direct blob IDs accepted from clients;
- background jobs processing attachment IDs;
- administrative access;
- downloads/exports;
- previews and variants;
- purge operations.

Do not expose a generic `ActiveStorage::Blob.find(params[:id])` endpoint for tenant-private files without an explicit authorization boundary.

A blob can outlive the controller/request that created it, so authorization must be applied at every access boundary.

Use `rails-security` and `rails-security-engineering` for threat modeling and tenant-isolation review.

## Storage service selection

Choose a storage service from workload and operational requirements:

- local disk for development/test or intentionally local deployments;
- object storage for production durability/scale;
- provider-specific services when the repository already standardizes on them;
- mirror services during controlled migration/replication scenarios.

Evaluate:

- durability;
- region/data residency;
- latency;
- egress cost;
- lifecycle/retention;
- encryption;
- access policy;
- provider limits;
- credentials/identity;
- backup/recovery;
- observability.

Do not choose public object storage merely because it makes URLs easy.

## Environment separation

Use environment-specific service selection and bucket/container separation where appropriate.

Verify:

- development cannot point at production data;
- test uses an isolated test service;
- staging cannot accidentally mutate production objects;
- bucket/container names encode environment where appropriate;
- credentials have least privilege;
- lifecycle policies match retention requirements.

Do not rely solely on convention such as "this config file is only used in staging."

## Provider boundary

Treat object storage as an external dependency.

Define:

- authentication method;
- bucket/container;
- region/endpoint;
- upload/download timeouts;
- retry behavior;
- provider rate limits;
- error classification;
- encryption options;
- lifecycle rules.

For S3-compatible providers, isolate provider-specific options in storage configuration.

Do not embed provider SDK calls in controllers/models when Active Storage can own the storage boundary.

Coordinate provider-specific HTTP behavior with `rails-api-integration`, `rails-reliability-engineering`, and `ruby-dependency-injection` where custom adapters are required.

## Storage failure semantics

Distinguish:

- database attachment state;
- object existence;
- upload completion;
- analysis completion;
- variant generation;
- download availability.

A successful database write does not prove the requested file is safely retrievable in every storage scenario.

Define behavior for:

- provider timeout;
- transient upload failure;
- missing object;
- permission denial;
- quota/rate limit;
- corrupted object;
- analysis failure;
- variant processing failure.

Do not retry every storage error blindly.

Use bounded retries for plausibly transient failures and surface permanent/authentication errors.

## Direct uploads

Direct uploads move file bytes from the browser to storage instead of through the application server.

Before enabling them, verify:

- upload endpoint/authentication;
- allowed storage service;
- CORS policy;
- maximum request/file size;
- content policy;
- signed blob creation;
- final attachment ownership;
- cleanup of blobs uploaded but never attached;
- client-side progress/error behavior.

The application server still owns domain authorization.

Do not assume direct upload makes an upload trusted because the browser successfully received a signed ID.

Direct upload is primarily a network/capacity architecture change, not a security bypass.

## Direct-upload lifecycle

Model the lifecycle explicitly:

```text
select file
-> obtain upload token/instructions
-> upload bytes
-> create/persist blob
-> receive signed blob identifier
-> attach to authorized record
-> analyze/process
```

A failure between "blob uploaded" and "record attached" can leave an unattached object.

Plan cleanup for unattached uploads.

If the application requires transactionally coupled business state and attachment, design the attachment commit boundary explicitly rather than assuming the object-store write participates in the database transaction.

## CORS

For browser-to-object-storage direct uploads, CORS is part of the security contract.

Review:

- allowed origins;
- allowed methods;
- request headers;
- credential behavior;
- exposed headers;
- preflight behavior;
- environment-specific origins.

Keep the allowlist narrow.

Never use a wildcard CORS policy for private production uploads unless the actual threat model explicitly permits it.

## File validation

Validate files at the application boundary.

Review:

- maximum byte size;
- attachment count;
- declared content type;
- extension;
- filename;
- business-purpose allowlist;
- archive/container policy;
- image/video/PDF processing requirements.

Treat uploaded bytes as untrusted even when the filename and declared MIME type look correct.

For high-risk file types or untrusted documents, consider content inspection or malware scanning before making the file broadly accessible.

Never execute uploaded files as code.

## Filenames and metadata

Treat filenames and metadata as untrusted input.

Normalize or safely encode filenames at display boundaries.

Do not construct filesystem paths from raw user filenames.

Avoid logging sensitive filenames or metadata unnecessarily.

Do not use filenames as stable identifiers.

The Active Storage blob key, not the original filename, should be treated as the storage identity.

## Serving private files

Default private storage should remain private unless a public access contract is explicit.

Decide between:

- redirect to service URL;
- application proxy;
- authenticated controller;
- CDN-backed proxy.

For tenant/private files, define authorization before issuing a file URL.

Be especially careful with signed URLs: possession of a usable URL can itself be the access capability.

Rails documents that default Active Storage controllers are publicly accessible and that signed blob URLs can remain usable by anyone who knows the URL; higher-protection applications should use authenticated controllers and can disable the generated routes.

Do not rely on a global `before_action` alone to protect Active Storage's default controllers.

## Public files

Public access is a data-classification decision.

Before enabling public storage, verify:

- file contents are intentionally public;
- bucket/container policy is correct;
- existing objects are consistent with the new policy;
- cache/CDN behavior is understood;
- deletion/retention is compatible;
- tenant-private resources cannot accidentally attach public storage.

Never switch private storage to public as a debugging shortcut.

## Authenticated file controllers

When stronger protection is required:

1. expose a domain-owned resource route;
2. authenticate the caller;
3. authorize the resource;
4. resolve the attachment through the authorized owner;
5. generate the file response/redirect;
6. disable conflicting public Active Storage routes when appropriate.

Keep authorization tied to the domain resource rather than an arbitrary blob ID.

## Download and memory usage

Downloading a file into process memory can create large memory spikes.

Choose streaming/proxy/tempfile approaches according to the workload.

For external processors, prefer opening/downloading to a temporary file rather than loading large files into Ruby memory when the library supports it.

Inspect:

- maximum object size;
- Puma/job concurrency;
- worker memory;
- transformation concurrency;
- external process limits.

A file endpoint can become a memory-amplification path even when the database query is trivial.

Use `rails-performance`, `ruby-performance`, and `rails-production-runtime` for capacity analysis.

## Analysis

Active Storage can analyze uploaded files asynchronously and persist metadata.

Treat analysis as eventually completed state.

Ask:

- does the business flow require analysis before use?
- what happens when analysis fails?
- which metadata is required?
- who owns analyzer configuration?
- what happens for unsupported/malformed files?
- does downstream logic distinguish "uploaded" from "analyzed"?

Do not assume upload completion means all metadata is already available.

When analysis is security-sensitive, gate access or downstream processing on the appropriate completion state.

## Variants and previews

Variants/previews are derived representations, not original assets.

Define:

- transformation contract;
- accepted source types;
- output format;
- size/dimensions;
- processing cost;
- caching/variant reuse;
- authorization;
- failure behavior.

Prefer stable, named variant transformations over scattered ad hoc processor options.

Do not allow user-controlled transformation parameters to create unbounded CPU/memory work.

For known hot representations, consider preprocessed variants and capacity implications.

## Processing dependencies

Image/video/PDF transformations may require external tools such as libvips/ImageMagick, ffmpeg, or PDF utilities.

Verify:

- installed versions;
- production availability;
- licensing;
- resource limits;
- security posture;
- failure behavior;
- container/package reproducibility.

Do not assume a transformation works in production because it works on a developer laptop.

## Background processing

Analysis and variant generation can enqueue Active Job work.

Compose with `rails-active-job` for:

- queue selection;
- retry/discard;
- idempotency;
- transaction semantics;
- concurrency;
- shutdown;
- observability.

Do not duplicate job retry logic inside attachment callbacks.

A large media workload must be sized against worker capacity and external processing limits.

## Replacement and deletion semantics

For `has_one_attached`, distinguish:

- replacing the attachment relationship;
- deleting the attachment;
- purging the blob;
- deleting the underlying object.

For `has_many_attached`, distinguish:

- adding attachments;
- replacing the collection;
- removing selected attachments;
- purging old files.

Define whether old files must be retained for audit/history or deleted immediately.

Do not call destructive purge operations from a request path unless latency, failure, and retry behavior are explicitly acceptable.

## Purge lifecycle

Purge can remove the object and associated Active Storage records.

Define:

- who is allowed to purge;
- when purge happens;
- whether purge is immediate or asynchronous;
- what happens when storage deletion fails;
- orphan/unattached cleanup policy;
- retention windows.

For user-facing deletes, consider durable domain state first and asynchronous cleanup second when appropriate.

Do not assume attachment deletion and physical object deletion have identical timing.

## Unattached and orphaned uploads

Direct uploads and interrupted workflows can create unattached blobs.

Define:

- maximum allowed unattached age;
- cleanup schedule;
- safe exceptions;
- dry-run/reconciliation procedure;
- metrics for orphan count/age;
- authorization for destructive cleanup.

Never purge unattached blobs merely because they are not currently attached without considering legitimate staged-upload workflows.

## Storage migration and mirrors

When changing providers:

1. inventory existing blobs;
2. define source-of-truth service;
3. copy historical data;
4. configure mirroring if appropriate;
5. monitor replication gaps/failures;
6. verify all files before cutover;
7. switch reads/writes deliberately;
8. retain rollback capability;
9. retire the old service only after reconciliation.

Rails documents mirrors as useful for temporary production migration and explicitly notes that mirroring is not atomic.

Do not describe a mirror as a transactional replica.

## CDN and proxy

If using a CDN, decide whether Active Storage redirect or proxy mode owns delivery.

Review:

- cache keys;
- URL expiry;
- authorization semantics;
- private/public classification;
- CDN host configuration;
- purge/cache invalidation;
- range requests;
- content-disposition behavior.

Do not cache tenant-private content at a shared CDN layer without proving cache-key and authorization isolation.

Compose with `rails-caching` when caching semantics become part of the file-access contract.

## Observability

Track the file lifecycle rather than only application exceptions.

Useful bounded dimensions include:

- attachment/model type;
- operation (upload, attach, download, purge, analyze, variant);
- storage service;
- outcome class;
- latency;
- retry count;
- file-size bucket;
- processing type.

Avoid logging:

- signed IDs;
- private blob URLs;
- access tokens;
- credentials;
- full filenames when sensitive;
- raw file contents.

Correlate asynchronous analysis/variant jobs with the initiating request or business operation where safe.

Use `rails-observability` for instrumentation and `rails-incident-engineering` for operational diagnosis.

## Testing

Test at the smallest boundary that proves the file contract.

Include:

- attachment association behavior;
- validation of size/content policy;
- replacement versus additive semantics;
- authorization and tenant isolation;
- direct-upload completion/ownership;
- authenticated download;
- private/public access contract;
- variant/preview behavior;
- purge behavior;
- unattached cleanup;
- provider failure handling;
- Active Job analysis/processing behavior;
- test storage isolation.

Use the Active Storage test service and local fixtures rather than live cloud providers in ordinary CI tests.

Do not make the test suite depend on networked object storage unless that is an intentional integration environment.

## Reference example

One attachment with an explicit, validated file contract, served only after authorization.

```ruby
class Document < ApplicationRecord
  has_one_attached :file

  ALLOWED_TYPES = %w[application/pdf image/png].freeze
  MAX_BYTES = 25.megabytes

  validate :enforce_file_contract

  private

  def enforce_file_contract
    return unless file.attached?

    errors.add(:file, "exceeds 25 MB") if file.byte_size > MAX_BYTES
    errors.add(:file, "must be PDF or PNG") unless file.content_type.in?(ALLOWED_TYPES)
  end
end

class DocumentsController < ApplicationController
  def show
    document = current_account.documents.find(params[:id]) # authorize before serving bytes
    redirect_to document.file.url(disposition: :attachment)
  end
end

# Variants are processed on demand and cached; never inline-transform in a request:
#   document.file.variant(resize_to_limit: [800, 800]).processed.url
```

## Agent review checklist

- [ ] Active Storage/version semantics resolved
- [ ] attachment ownership/cardinality explicit
- [ ] upload authorization explicit
- [ ] tenant isolation reviewed
- [ ] file size/type/content policy explicit
- [ ] storage service/environment separation verified
- [ ] provider credentials protected
- [ ] direct-upload lifecycle reviewed
- [ ] CORS reviewed when applicable
- [ ] private/public access decision explicit
- [ ] authenticated download boundary verified when required
- [ ] signed URL exposure understood
- [ ] download memory/capacity reviewed
- [ ] analyzer/variant dependencies verified
- [ ] background processing semantics reviewed
- [ ] replacement/delete/purge semantics explicit
- [ ] unattached-upload cleanup bounded
- [ ] mirror/migration reconciliation verified when applicable
- [ ] CDN/proxy caching reviewed when applicable
- [ ] observability excludes secret/blob data
- [ ] focused Active Storage tests exist
- [ ] live provider dependency avoided in ordinary CI

## Anti-patterns / failure modes

- using a blob ID as authorization;
- exposing Active Storage default routes for tenant-private files;
- switching private storage to public to simplify access;
- trusting browser MIME type as a security control;
- executing or serving uploaded files as application code;
- loading huge files fully into Ruby memory;
- unbounded user-controlled transformations;
- synchronous cloud deletion on critical request paths without need;
- assuming analysis is complete immediately after upload;
- assuming attachment delete means physical object delete is already complete;
- blindly purging every unattached blob;
- treating mirror replication as atomic;
- leaking signed URLs into logs;
- granting storage credentials broader permissions than required;
- testing ordinary application behavior against a real cloud bucket;
- duplicating Active Storage provider SDK logic in domain models/controllers.

## Verification

For an upload feature:

```text
attachment contract
-> validation
-> authorization
-> storage configuration
-> focused attachment tests
-> direct-upload/serving tests where applicable
-> processing/background tests
-> security checks
-> regression suite
```

For storage migration:

```text
inventory
-> copy
-> reconcile
-> mirror/dual-read evidence when used
-> cutover
-> verify reads/writes
-> verify gaps
-> retire old provider
```

Never claim storage durability, complete replication, or successful migration without provider/runtime evidence.

## Source foundation

Primary Rails source:

- https://guides.rubyonrails.org/active_storage_overview.html
- https://api.rubyonrails.org/classes/ActiveStorage.html

Composed repository skills:

- `skills/rails-security/SKILL.md`
- `skills/rails-security-engineering/SKILL.md`
- `skills/rails-active-job/SKILL.md`
- `skills/rails-api-integration/SKILL.md`
- `skills/rails-performance/SKILL.md`
- `skills/rails-caching/SKILL.md`
- `skills/rails-observability/SKILL.md`
- `skills/rails-production-runtime/SKILL.md`
- `skills/rails-test-engineering/SKILL.md`
- `skills/rails-test-engineering/SKILL.md`

## Rails Active Storage changes

For Active Storage changes:
- inspect attachment declarations, domain ownership, tenant rules, storage configuration, routes, direct-upload code, processing jobs, purge behavior, and tests before implementation;
- treat the uploaded file as untrusted data and the blob identifier as an object reference, not as authorization;
- define attachment cardinality, replacement/additive semantics, validation, retention, and purge behavior explicitly;
- keep production storage services and credentials environment-isolated and least-privileged;
- treat browser direct uploads as a staged lifecycle: upload, attach to an authorized resource, process/analyze, then clean up unattached blobs;
- review CORS, file-size/content policy, signed URLs, default Active Storage routes, proxy/redirect mode, and authenticated access for private files;
- bound download memory, transformation CPU/memory, processing concurrency, and background retry behavior;
- distinguish logical attachment removal from physical object purge;
- reconcile storage migrations/mirrors rather than assuming replication is atomic;
- use the Active Storage test service and deterministic fixtures for ordinary CI; avoid live cloud-provider dependence;
- never claim storage durability, complete migration, replication completeness, or file delivery success without provider/runtime evidence.
