---
name: rails-action-text
description: "Use when designing, implementing, reviewing, testing, or operating Rails Action Text rich-text content, Trix editors, RichText associations, sanitization, embedded attachments, Signed Global IDs, rendering, API boundaries, localization, or rich-text performance."
---

# Rails Action Text Engineering

## Purpose

Treat Action Text rich content as a persisted presentation and attachment boundary with its own security, authorization, rendering, performance, and compatibility contracts.

Action Text provides the Trix editor and persists rich content through ActionText::RichText rather than a text column on the owning model. Embedded files can use Active Storage, while non-storage attachables can be referenced through Signed Global IDs. Rails sanitizes Action Text rich content before safe HTML rendering.

Core flow:

```text
define rich-text ownership
-> define content/format contract
-> authorize editing
-> validate/sanitize input
-> persist RichText
-> resolve attachments/attachables
-> render safely
-> preload efficiently
-> expose through API/mail/feed
-> test lifecycle/security
```

## Activate when

- adding `has_rich_text`;
- adding or changing `ActionText::RichText`;
- adding `rich_textarea` or Trix editor behavior;
- changing rich-text sanitization;
- customizing Action Text rendering/layouts/partials;
- embedding Active Storage files in rich text;
- embedding Signed Global ID attachables;
- exposing rich text through APIs;
- changing rich-text edit/update authorization;
- diagnosing missing embedded attachments or unresolved attachables;
- investigating Action Text N+1 queries or rendering performance;
- localizing rich text or editor content;
- testing rich-text content, attachments, or sanitization;
- upgrading Trix/Action Text behavior.

Do not activate merely because a model contains a plain text column. Use `rails-action-view`, `rails-active-record`, or `rails-i18n` unless the Action Text boundary exists.

## Repository inspection

Inspect before changing Action Text:

1. Ruby/Rails and Action Text/Trix versions;
2. `has_rich_text` declarations and naming conventions;
3. Action Text migrations and RichText schema;
4. Trix/application JavaScript integration;
5. `rich_textarea` forms and permitted attributes;
6. Action Text layouts and blob/attachable partials;
7. sanitization configuration and HTML-safe rendering;
8. authorization/policy around the owning record;
9. Active Storage service and upload rules;
10. Signed Global ID / GlobalID usage;
11. custom attachable implementations;
12. API serializers and rich-text wire format;
13. localized rich-text/editor behavior;
14. `with_rich_text_*` scopes and query patterns;
15. cache/CDN behavior for rendered HTML;
16. tests, fixtures, system tests, and JavaScript tests;
17. security scanners and CSP/HTML policies.

Do not introduce a second rich-text model or editor abstraction without repository evidence.

## Ownership boundary

Action Text attaches rich content to an owning Active Record model.

Define:

- owner/resource;
- rich-text attribute;
- who may create/update/delete it;
- tenant/account scope;
- retention/deletion semantics;
- whether embeds may reference external/domain objects;
- whether content can be public or private.

`ActionText::RichText` existence is not equivalent to authorization.

Do not expose or mutate arbitrary RichText rows through a generic ID endpoint without authorizing the owning record.

Prefer editing through the domain resource that owns the rich-text field.

## Content contract

Define what the rich text is for.

Examples:

- article body;
- comment;
- support note;
- product description;
- internal documentation;
- user profile biography.

The contract should state:

- allowed formatting;
- links;
- tables/lists if supported;
- embeds/attachments;
- maximum content size;
- permitted HTML elements/attributes;
- URL policy;
- whether content is public/private;
- whether historical versions are retained.

Do not allow arbitrary HTML simply because Action Text stores HTML-like content.

Treat rich text as structured untrusted user input at the write boundary even though Action Text sanitizes content for rendering.

## Editing authorization

Authorization happens before the content is persisted.

For update flows verify:

- authenticated actor;
- resource ownership/tenant;
- edit permission;
- content purpose;
- allowed attachment/embed policy.

The controller/form may permit the rich-text attribute, but authorization must still be evaluated against the owning resource.

Do not authorize arbitrary `ActionText::RichText.find(params[:id])` updates.

Do not infer authorization from a Signed Global ID.

Compose with `rails-security` and `rails-security-engineering`.

## Trix/editor boundary

Trix is the browser editing interface, not the application's authorization layer.

Review:

- imported Trix/@rails/actiontext assets;
- editor toolbar/custom actions;
- direct-upload events for attachments;
- pasted HTML/content behavior;
- client-side limits;
- server-side validation/sanitization;
- browser compatibility.

Client-side restrictions are usability controls.

Never rely on editor JavaScript to enforce a security or tenant boundary.

## Sanitization boundary

Action Text sanitizes rich text before safe rendering.

That does not remove the need to reason about the input boundary.

Review:

- allowed tags;
- allowed attributes;
- links and URL schemes;
- custom renderers;
- custom sanitizers;
- `html_safe`/raw usage around content;
- translation/interpolation into rich text;
- pasted or imported HTML;
- custom attachment partials.

Never mark raw user HTML safe merely because it came from a Trix editor.

Do not bypass Action Text's sanitization without documenting the exact trusted content model and security review.

If a custom sanitizer is used, test both permitted formatting and malicious payload rejection.

Coordinate with `rails-security` for XSS and content-security review.

## Links and URLs

Rich text can contain hyperlinks.

Define and review:

- allowed URL schemes;
- external versus internal links;
- host restrictions when required;
- tracking parameters;
- target/rel attributes where applicable;
- link rendering policy.

Treat pasted links as untrusted.

Do not assume a link is safe because the editor generated the anchor element.

If application-specific URL rewriting is used, keep it deterministic and tested.

## Attachments

Action Text can embed Active Storage attachments.

Composition boundary:

```text
Action Text content
      |
attachment reference
      |
Active Storage / blob
      |
object storage
```

Use `rails-active-storage` for:

- upload policy;
- storage services;
- direct uploads;
- object access;
- variants;
- purge;
- storage migration.

This skill owns how embedded attachments participate in rich-text content and rendering.

Do not duplicate Active Storage provider/storage guidance here.

## Signed Global ID attachables

Action Text can embed attachables resolved through Signed Global IDs.

Treat an SGID as a signed reference, not as an unconditional authorization grant.

Before allowing an object to be embedded verify:

- the caller may reference the object;
- the object belongs to the appropriate tenant/context;
- the object exposes only intended presentation data;
- the object has a safe attachable partial;
- missing/deleted records have deterministic fallback behavior.

Never let a user embed arbitrary privileged objects merely because they can construct or obtain a signed identifier.

Review SGID purpose, expiry, and application-specific verifier configuration where applicable.

## Attachables and rendering

An attachable may render through a domain-owned partial.

Define:

- partial path;
- local variable contract;
- public/private presentation;
- missing-object fallback;
- N+1 behavior;
- authorization assumptions.

The attachable partial is part of the rich-text output boundary.

Do not render sensitive model attributes merely because the attachable object contains them.

Prefer a purpose-built presentation shape over exposing a full domain model.

## Missing attachables

Records referenced by rich text can later be deleted or become unavailable.

Define the contract for unresolved attachables:

- placeholder;
- omitted content;
- fallback partial;
- broken-reference marker;
- error/reporting behavior.

Do not let deleted records cause uncontrolled rendering exceptions across every document containing an old reference.

Test both existing and missing attachables.

## Rendering boundary

Action Text rich content is presentation output.

Prefer the framework's RichText rendering path rather than:

- parsing HTML manually;
- calling raw `html_safe` on stored bodies;
- duplicating sanitizer logic;
- reconstructing Trix markup in controllers.

ActionText::RichText#to_s is designed to produce safe HTML for rendering, while `to_plain_text` is not HTML-safe and should not be rendered directly in a browser without sanitization.

Treat plain-text extraction as a separate representation contract.

## API boundary

Do not expose internal Action Text storage tables as a public API contract.

For APIs decide whether clients receive:

- rendered HTML;
- sanitized HTML plus plain text;
- editor/document representation;
- structured attachment metadata;
- stable content/version identifiers.

Define the representation explicitly.

For write APIs:

```text
request content
-> validate/authorize
-> persist RichText
-> respond with stable representation
```

Do not make API clients depend on internal RichText primary keys, attachment table rows, or Trix-specific implementation details unless intentionally part of the contract.

Coordinate with `rails-api-integration`.

## Rich text and localization

If rich text content is locale-dependent, define whether localization is:

- separate rich-text fields per locale;
- translation keys inside content;
- localized presentation around a shared body;
- external translation workflow.

Do not interpolate user-provided rich text into translation strings.

Do not assume a single RichText body can satisfy all language/grammar requirements when the actual content differs materially.

Use `rails-i18n` for locale context, locale resolution, and localized surrounding presentation.

## Forms and parameters

Permit rich-text attributes explicitly at the owning resource boundary.

Inspect:

- strong parameters;
- nested resources;
- form objects;
- API payload size limits;
- content upload handling.

Do not permit arbitrary RichText IDs or attachment IDs merely to simplify form submission.

Use `rails-action-controller` and `rails-validations` for request/input contracts.

## Persistence and lifecycle

The owning model can have rich text persisted outside its primary table.

Review:

- creation/update lifecycle;
- transaction boundaries;
- deletion behavior;
- dependent cleanup;
- callbacks/jobs;
- migration compatibility.

Keep domain state and rich-text lifecycle behavior explicit.

Do not assume a model delete has exactly the same operational timing as embedded attachment/object deletion.

Coordinate attachment cleanup with `rails-active-storage`.

## Performance and N+1

Rich text rendering can load associated RichText and embedded attachments.

Rails provides preloading scopes such as:

- `with_rich_text_<name>`;
- `with_rich_text_<name>_and_embeds`.

Use the appropriate preload when rendering collections.

Before optimizing:

1. measure query count;
2. identify whether RichText or embeds cause the N+1;
3. choose the narrowest preload;
4. measure again.

Do not preload every rich-text and every embed on every query merely because one page needs them.

For large content or high-fanout pages inspect rendering size, attachment transformations, cache behavior, and memory.

Compose with `rails-performance`, `rails-active-record`, and `ruby-performance`.

## Caching rendered rich text

Rendered HTML may be cached, but its cache identity must include all correctness dimensions.

Review:

- locale;
- resource/content version;
- attachment/variant state;
- permission/public-private scope;
- sanitizer/configuration changes;
- custom attachable rendering;
- deployment compatibility.

Do not cache private rich text across users/tenants.

Do not assume a cache key based only on owner ID is sufficient when rich-text content or rendering dependencies vary.

Compose with `rails-caching` and `rails-i18n`.

## Content size and resource limits

Rich text can become a resource-exhaustion vector through:

- huge bodies;
- many embeds;
- deeply nested markup;
- repeated transformations;
- large attachment sets;
- expensive rendering.

Define practical limits where the product permits:

- maximum content length;
- maximum embedded attachments;
- maximum attachment size;
- allowed markup complexity;
- transformation constraints.

Server-side enforcement is authoritative.

Do not rely solely on Trix editor limits.

## Background work

Rich-text processing may interact with Active Storage analysis, variants, notifications, indexing, or publishing workflows.

Define:

- synchronous versus asynchronous processing;
- transaction/commit semantics;
- retry behavior;
- idempotency;
- stale content handling.

Do not make rendering depend on a background job having already completed unless that is explicit in the contract.

Compose with `rails-active-job`.

## Search/indexing

If rich text is indexed for search, define the indexed representation.

Possible choices:

- plain text extracted from RichText;
- sanitized text;
- rendered HTML stripped by a dedicated parser;
- custom normalized search document.

Do not index raw HTML as if it were canonical search content without understanding tokenization/noise.

Treat indexing as derived state and define rebuild/reconciliation behavior.

Coordinate with `rails-database-engineering` and `rails-distributed-systems` if indexing is asynchronous or external.

## Security and privacy

Rich text is user-controlled content that can contain links, embedded files, and references to application objects.

Review:

- XSS/sanitization;
- link schemes;
- attachable authorization;
- tenant isolation;
- sensitive attachment rendering;
- signed Global ID usage;
- public/private visibility;
- logs/errors;
- cache isolation;
- translation/admin content;
- API exposure.

A sanitized body can still render a private attached resource incorrectly if attachment authorization is wrong.

Never treat successful sanitization as proof that the user was authorized to reference every embedded object.

## Testing

Test at the smallest owning boundaries:

- rich-text association;
- editor submission;
- permitted attribute;
- authorization;
- sanitization;
- malicious HTML/link handling;
- attachment embedding;
- attachable SGID authorization;
- missing attachable fallback;
- HTML rendering;
- plain-text extraction;
- API representation;
- localized rich-text behavior;
- preload/query behavior;
- cache identity;
- delete/lifecycle behavior;
- background processing when applicable.

Use deterministic Action Text/Active Storage test support and fixture data.

Do not make ordinary tests depend on external cloud storage or a browser session unless that behavior is the actual contract.

For XSS/security regressions, add negative tests containing representative malicious markup and URL schemes.

## Reference example

Rich text declared on the model, rendered through its sanitized fragment, never through html_safe of editor input.

```ruby
class Article < ApplicationRecord
  has_rich_text :body

  validates :body, presence: true
end

# app/views/articles/_form.html.erb:
#   <%= f.rich_text_area :body %>
#
# Rendering contract:
#   article.body.to_s  -> sanitized HTML fragment, safe for templates and API payloads
#   Direct editor input is never trusted; sanitization happens on save, not on render.
#
# Attachments inside rich text are signed Global ID attachables:
#   ActionText::Attachment carries sgid://... references resolved server-side.
```

## Agent review checklist

- [ ] Action Text/Rails version resolved
- [ ] rich-text owner and attribute explicit
- [ ] edit authorization checked
- [ ] content contract defined
- [ ] server-side sanitization preserved
- [ ] link/URL policy reviewed
- [ ] attachment boundary composed with Active Storage
- [ ] SGID attachable authorization reviewed
- [ ] attachable rendering/fallback defined
- [ ] API representation explicit
- [ ] locale behavior explicit when applicable
- [ ] persistence/deletion lifecycle reviewed
- [ ] N+1/preloading measured
- [ ] rendered rich-text cache identity reviewed
- [ ] content/resource limits defined
- [ ] background processing semantics reviewed
- [ ] search/indexing representation defined when applicable
- [ ] security/privacy tests added
- [ ] deterministic rich-text tests exist

## Anti-patterns / failure modes

- authorizing arbitrary RichText by ID;
- treating Signed Global IDs as authorization by themselves;
- trusting Trix/client-side validation;
- disabling/bypassing sanitization for convenience;
- marking raw Action Text body HTML-safe manually;
- allowing arbitrary attachable objects;
- rendering private attachments through public rich-text pages;
- duplicating Active Storage provider logic inside Action Text code;
- exposing ActionText::RichText table structure as an API;
- rendering large collections without RichText/embed preload;
- globally preloading every rich-text body/embed;
- caching private rich text without permission identity;
- assuming missing attachables never occur;
- using locale to authorize content;
- allowing unbounded rich-text/attachment payloads;
- relying on background processing without defining its failure state.

## Verification

For a rich-text feature:

```text
ownership
-> edit authorization
-> content/input contract
-> sanitization
-> attachment/attachable authorization
-> rendering contract
-> API/localization contract
-> performance/preload review
-> focused security tests
-> regression suite
```

For a rendering incident distinguish:

```text
stored RichText
-> sanitizer
-> attachable resolution
-> attachment/blob rendering
-> localized presentation
-> preload/query behavior
-> cache
-> final HTML
```

Never claim rich-text safety merely because the content originated in Trix. Verify server-side sanitization, attachment authorization, attachable resolution, and final rendering behavior.

## Source foundation

Primary Rails source:

- https://guides.rubyonrails.org/action_text_overview.html
- https://api.rubyonrails.org/classes/ActionText/RichText.html

The Rails guide documents Trix, RichText persistence, sanitized HTML rendering, Active Storage attachments, Signed Global ID attachables, custom attachment rendering, and preloading RichText/embeds.

Composed repository skills:

- `skills/rails-active-record/SKILL.md`
- `skills/rails-action-view/SKILL.md`
- `skills/rails-validations/SKILL.md`
- `skills/rails-active-storage/SKILL.md`
- `skills/rails-security/SKILL.md`
- `skills/rails-security-engineering/SKILL.md`
- `skills/rails-i18n/SKILL.md`
- `skills/rails-caching/SKILL.md`
- `skills/rails-performance/SKILL.md`
- `skills/ruby-performance/SKILL.md`
- `skills/rails-api-integration/SKILL.md`
- `skills/rails-active-job/SKILL.md`
- `skills/rails-test-engineering/SKILL.md`
- `skills/rails-test-engineering/SKILL.md`

## Rails Action Text changes

For Action Text/rich-text changes:
- inspect has_rich_text declarations, Action Text/Trix versions, RichText schema, editor integration, sanitization, custom partials, attachment/attachable behavior, APIs, locale behavior, query patterns, and tests before implementation;
- authorize editing through the owning domain resource; never treat ActionText::RichText IDs or Signed Global IDs as authorization by themselves;
- preserve Action Text server-side sanitization and review custom HTML/link/attachment rendering for XSS and privacy risks;
- treat Trix/client-side validation as usability only; server-side authorization and content controls remain authoritative;
- use rails-active-storage for embedded file storage/access lifecycle rather than duplicating storage-provider logic in Action Text code;
- restrict and explicitly authorize attachable object types, tenant scope, and rendering partials; define missing-record fallback;
- keep public API representations stable and avoid exposing internal RichText/attachment table structure unless explicitly contractual;
- measure RichText and embed query behavior before choosing `with_rich_text_*` preloads; use the narrowest preload justified by the rendering workload;
- review locale and cache identity when rendered rich text varies by locale, permission, content version, or attachment state;
- bound rich-text size, attachment count, and transformation work where product requirements allow;
- coordinate lifecycle/cleanup semantics across RichText and Active Storage instead of assuming external object deletion is transactional;
- add negative security tests for malicious HTML/URLs and unauthorized embedded resources;
- use deterministic local/test storage and avoid live cloud-provider dependencies in ordinary CI;
- never claim rich-text safety merely because the content came from Trix; verify sanitization, authorization, attachable resolution, and final rendering.
