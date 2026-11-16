---
name: rails-action-controller
description: Use when implementing or reviewing Rails Action Controller HTTP boundaries including parameters, request and response semantics, sessions, cookies, callbacks, negotiation, conditional responses, streaming, and controller-level exception handling. Also covers routine controller actions, parameters, rendering, and redirects.
---

# Rails Action Controller

## Purpose

Treat Action Controller as the HTTP execution boundary between routing and application behavior.

The controller owns request interpretation, boundary input filtering, request-scoped state access, response construction, and controller-level HTTP lifecycle behavior. It should not become the owner of domain invariants, persistence workflows, authorization policy, external provider orchestration, or durable messaging merely because those concerns are reachable from an action.

## Activate when

- adding or changing Action Controller behavior beyond a simple CRUD action
- rendering Markdown responses with `render markdown:`
- changing params, strong parameters, nested input, or request metadata
- changing render, redirect, status, headers, content type, or response body behavior
- adding or changing sessions, cookies, or flash state
- adding or changing before_action, after_action, or around_action
- implementing HTML/JSON/XML or other request-format negotiation
- adding ETag, Last-Modified, conditional GET, or HTTP cache validators
- adding file downloads, streaming, or large response handling
- adding controller-level exception mapping with rescue_from
- debugging unexpected dispatch, double renders, missing responses, or request/response behavior

For a simple CRUD action, params handling, or a status/render/redirect change, `rails-action-controller` is the lighter entry point; activate this skill only when the deeper boundaries above are actually in play.

## Boundary ownership

| Concern | Controller owns | Prefer another boundary |
|---|---|---|
| HTTP parameter parsing/filtering | yes | domain validation for semantic rules |
| request metadata | yes | business identity derivation |
| authentication orchestration | boundary hook/collaborator | rails-authentication |
| authorization decision | invocation of existing policy | rails-security / policy boundary |
| persistence | orchestration | rails-active-record / database skill |
| business workflow | invocation | service/domain object |
| response mapping | yes | serializer/view for representation |
| sessions/cookies/flash | yes | auth/session subsystem for identity semantics |
| instrumentation | emit/observe | rails-observability |
| cache correctness | HTTP validator interaction | rails-caching |
| API provider calls | no | rails-api-integration |
| durable async work | enqueue/delegate | rails-active-job / messaging |
| route declaration | no | rails-routing |

## Repository inspection

Before changing a controller boundary, inspect:

1. Ruby and Rails versions.
2. config/routes.rb and the matching controller/action.
3. ApplicationController and inherited callbacks/modules.
4. Authentication and authorization hooks.
5. Existing parameter filtering conventions.
6. Request/response format conventions.
7. Session, cookie, and flash configuration.
8. Error handling and rescue_from mappings.
9. View/serializer/representation contracts.
10. HTTP cache validator and CDN/proxy conventions.
11. File/streaming/download helpers already used.
12. Request/integration/system tests and shared controller helpers.
13. Observability and log-filtering conventions.
14. Neighboring controllers for local conventions.

Resolve version-sensitive APIs before implementation. Newer Rails releases support params.expect; older supported versions may require require plus permit.

## Request boundary

Treat every request value as untrusted input, including query parameters, body parameters, path parameters, headers, cookies, session-derived identifiers, format values, redirect targets, file names, and download options.

Translate these values into a narrow, explicit input contract before calling domain code.

Do not use request metadata as a substitute for authorization. A route, header, cookie, or parameter can identify context, but the owning authorization boundary decides whether an operation is permitted.

## Parameters and strong parameters

Use the repository's supported strong-parameter API.

For versions supporting params.expect, prefer it when the repository convention allows it because it can require and permit the expected structure in one boundary operation. Otherwise use require and permit deliberately.

Guidance:

- permit only fields the action is allowed to mutate or consume
- keep permitted shapes explicit
- treat nested arrays/hashes as deliberate contracts
- separate transport normalization from domain validation
- Do not use permit! merely to make an integration work
- do not permit fields just because the model has them
- avoid forwarding the entire params object into domain/persistence code
- test omitted, extra, malformed, and nested inputs.

Strong parameters are an input boundary, not an authorization system and not a substitute for domain validation.

## Request object semantics

Use the request object for HTTP facts, not domain state.

Review method, path, host, protocol, headers, query/body/path parameter separation, requested format, content type, and trusted proxy conventions.

Do not derive security-sensitive identity directly from forwarded headers without inspecting trusted proxy configuration and local conventions.

## Response contract

Every controller action should have an intentional response contract.

Review:

- status
- response format/content type
- body/render target
- redirect location
- headers
- caching validators
- empty-body semantics
- error representation
- content negotiation behavior.

Avoid accidental implicit rendering when the action requires a stable API or download contract. Conversely, do not add explicit render calls merely to restate normal Rails behavior when the repository relies on implicit rendering.

A redirect is a response; code after redirect_to can still execute. Return immediately when continuing could cause side effects or a second response.

Never create two response paths that can both render or redirect.

## Render and redirect semantics

For render:

- preserve repository view/serializer conventions
- verify status and content type for non-default responses
- keep representation decisions separate from domain logic
- distinguish rendering an error page from raising an exception.

For redirect:

- use stable route helpers or records when possible
- treat user-provided redirect targets as untrusted
- preserve Rails open-redirect protections
- use an explicit safe fallback for return-to flows
- choose redirect status deliberately for non-GET requests
- stop execution when redirect is terminal.

Do not enable cross-host redirects for untrusted input merely to preserve convenience behavior.

## Sessions, cookies, and flash

Treat session, cookie, and flash state as HTTP state with explicit lifecycle and privacy contracts.

Inspect the session store, cookie serializer, signed versus encrypted cookies, size limits, expiration/rotation behavior, authentication integration, and flash semantics.

Store the smallest state necessary. Do not put Active Record objects, secrets, authorization decisions, large collections, or sensitive provider responses into client-side cookie-backed state.

Signed cookies provide integrity protection; encrypted cookies add confidentiality. Neither means arbitrary application data should be stored there without an ownership and retention contract.

Do not infer authorization from the presence of a session value. Load and authorize the authoritative resource through the application's authentication/authorization boundary.

## Controller callbacks

Use callbacks for small, deterministic, cross-cutting request prerequisites such as authentication gating and resource loading.

For each callback verify affected actions, execution order, inherited callbacks, halting behavior, response state, and hidden database/network work.

Avoid callbacks that hide business workflows, external side effects, transactions, or large orchestration graphs.

When action order matters, make lifecycle assumptions explicit and test the affected action set.

## Content negotiation

Treat request format and content negotiation as part of the public HTTP contract.

Define supported formats explicitly. Verify route constraints, requested format, Accept behavior, request content type, HTML fallback, API error format, and unsupported-format behavior.

Do not silently add formats because a serializer or helper exists.

Keep API wire contracts composed through rails-api-integration; this skill owns controller-level negotiation and response dispatch.

## Conditional GET and HTTP cache validators

Use conditional responses when a resource can provide a stable representation and validators.

Review ETag strength/semantics, Last-Modified, Cache-Control, private/public cache scope, and whether the representation varies by identity, permission, locale, tenant, or other request context.

A 304 Not Modified response is a transport optimization, not proof that application state is unchanged forever.

Do not derive a shared public cache validator from private data without including all relevant identity dimensions. Coordinate representation cache correctness with rails-caching.

## Streaming and downloads

Use file/download or streaming helpers only when their lifecycle and resource costs are understood.

Inspect file ownership/authorization, content type, content disposition, file size, buffering versus streaming, client disconnect behavior, resource cleanup, timeouts, and concurrency impact.

Do not stream an unbounded database query, external provider, or object graph directly from a controller without a bounded producer and cleanup design.

For Active Storage objects, compose with rails-active-storage rather than duplicating storage access rules.

## Exception handling

Use controller-level exception mapping only for errors with an explicit HTTP contract.

A good rescue_from boundary:

- identifies the expected exception class
- maps it to a stable response
- preserves status/content-type semantics
- emits appropriate observability context
- does not hide programmer defects.

Do not catch StandardError broadly to turn unexpected failures into successful-looking responses.

Keep authentication/authorization failures distinct from not-found, domain conflicts, validation errors, and dependency failures.

Coordinate error reporting with rails-observability; do not duplicate global error reporting inside one controller.

## Security and privacy

Compose rather than duplicate rails-security and rails-security-engineering.

Controller-specific checks include strong parameter boundaries, authorization before sensitive lookup/use, open-redirect prevention, cookie/session sensitivity, CSRF behavior for browser sessions, response content-type correctness, download authorization, error-detail exposure, filtered logging, host/proxy trust, and tenant isolation.

Never log raw authorization headers, session contents, password/reset fields, or full request bodies containing secrets.

## Performance and capacity

Controllers are part of the request concurrency budget.

Review synchronous database work, synchronous external calls, serialization size, response buffering, streaming connection duration, callback fan-out, cache validation work, and repeated authorization/lookups.

Long-lived streaming responses consume concurrency and must be included in capacity planning.

Do not call an endpoint fast based on controller line count. Use measured request/query/allocation/network evidence from rails-performance, ruby-performance, and rails-observability.

## Testing

Choose the narrowest test that proves the HTTP contract, then add focused integration coverage where lifecycle interactions matter.

At minimum, test relevant:

- permitted and rejected input
- missing/extra/nested parameters
- authenticated versus unauthenticated requests
- authorized versus forbidden requests
- success status/body/format
- redirect target and status
- session/cookie/flash behavior
- callback scope
- unsupported formats
- conditional response behavior
- exception-to-response mapping
- download authorization and headers
- streaming lifecycle when used.

Use deterministic local doubles for external providers and storage.

## Reference example

A controller action with tenant-scoped lookup, strict strong parameters, and a declared exception-to-response mapping.

```ruby
class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show update destroy]
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def update
    if @invoice.update(invoice_params)
      render :show, status: :ok
    else
      render json: { errors: @invoice.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_invoice
    # Scoped lookup: never Invoice.find(params[:id]) in a multi-tenant app.
    @invoice = current_account.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:due_on, line_items_attributes: %i[id description amount _destroy])
  end

  def record_not_found
    head :not_found
  end
end
```

## Agent review checklist

- [ ] Rails/Ruby version resolved
- [ ] route/controller inheritance inspected
- [ ] authentication and authorization boundaries identified
- [ ] parameter contract is explicit
- [ ] request metadata is used only for HTTP concerns
- [ ] response status/body/format/headers are intentional
- [ ] redirects cannot create unsafe open redirects
- [ ] session/cookie payload is minimal
- [ ] callbacks are narrow and scoped
- [ ] supported formats are explicit
- [ ] conditional validators include required identity dimensions
- [ ] streaming/download lifecycle is bounded and authorized
- [ ] expected exceptions have explicit HTTP semantics
- [ ] sensitive values are not logged
- [ ] focused request tests cover failure and success paths
- [ ] cross-skill responsibilities remain explicit

## Failure modes

Avoid:

- forwarding all params into a model or service
- using validation success as authorization
- putting business workflows into before_action
- accepting arbitrary redirect_to params[:return_to]
- storing large/private state in cookie-backed sessions
- adding format branches without a contract
- generating cache validators from incomplete identity
- streaming without cleanup/backpressure/resource limits
- rescuing all exceptions into 200 OK
- assuming a hidden route provides security
- claiming caching or streaming improved performance without measurement.

## Verification

Run, as applicable:

1. focused request/controller tests
2. route verification when dispatch changed
3. security regression tests
4. serializer/view tests for representation changes
5. relevant observability/cache tests
6. bin/validate
7. the CI workflow for the branch.

Report actual test and CI evidence; never infer success from a clean diff.

## Source foundation

Primary current Rails sources:

- Rails Guide: Action Controller Overview — https://guides.rubyonrails.org/action_controller_overview.html
- ActionController::Parameters API — https://api.rubyonrails.org/classes/ActionController/Parameters.html
- ActionController::Redirecting API — https://api.rubyonrails.org/classes/ActionController/Redirecting.html
- ActionController::ConditionalGet API — https://api.rubyonrails.org/classes/ActionController/ConditionalGet.html
- ActionController::Rescue API — https://api.rubyonrails.org/classes/ActionController/Rescue.html

Framework behavior is interpreted against the repository's resolved Rails version and local conventions.

## Composition

This skill composes with rails-routing, rails-action-controller, rails-authentication, rails-security, rails-security-engineering, rails-api-integration, rails-observability, rails-caching, rails-active-storage, rails-active-job, rails-i18n, rails-test-engineering, rails-test-engineering, ruby-clean-code, and ruby-tdd-refactoring.

## Routine controller action changes

_Merged from the retired `rails-action-controller` skill._

### Repository inspection

Read:

- route declaration
- action and neighboring actions
- authentication/authorization patterns
- service/domain/model collaborators
- serializer/view
- request tests
- error response conventions

### Responsibilities

A controller generally:

1. receives request
2. establishes requester context
3. authorizes according to project convention
4. filters/normalizes boundary input
5. invokes application/domain behavior
6. maps result to HTTP response

Keep substantial business logic outside the action when it does not naturally belong at the HTTP boundary.

### Parameters

Treat incoming values as untrusted.

Use the repository's established strong-parameter or request validation approach.

Do not duplicate every model rule in the controller.

### Response contract

Verify:

- status
- headers where relevant
- render/template/serializer
- redirect destination
- response format
- error shape

A controller refactor must not silently change an API response.

### Error handling

Follow repository conventions for expected domain failures versus unexpected exceptions.

Do not use broad rescue clauses to hide programming errors.

### Action complexity

When an action becomes a workflow involving several concepts, consider a service/application object, but do not extract trivial code merely to shorten the controller.

### Security boundary

Do not assume hidden fields or UI state are trusted. Authorization must be enforced at the server boundary.

### Reference example

A plain CRUD controller: strong parameters, one lookup, explicit status, nothing else.

```ruby
class ProjectsController < ApplicationController
  def index
    @projects = current_user.projects.order(created_at: :desc)
  end

  def create
    @project = current_user.projects.build(project_params)

    if @project.save
      redirect_to @project, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
```

### Agent review checklist

- [ ] route/action relationship checked
- [ ] authentication/authorization behavior preserved
- [ ] params boundary explicit
- [ ] business logic owned elsewhere when appropriate
- [ ] response contract preserved
- [ ] expected and unexpected failures distinguished

### Verification

Use request/controller tests that exercise the actual HTTP contract: successful request, invalid input, unauthorized/forbidden behavior, not-found behavior where relevant, and expected response format.

### Book integration: controller filters

Controller callbacks such as before_action are useful for repeatable request prerequisites such as authentication and loading a resource. Keep the callback small and explicit.

Do not move arbitrary business workflows into callbacks. If the operation coordinates several domain steps, keep the callback as a boundary check and delegate the workflow elsewhere.

Always verify which actions are affected by a callback; an authentication filter intended for private actions must not accidentally protect public endpoints.

## Rails Action Controller changes

For Action Controller and deep controller-boundary changes:
- inspect the Rails/Ruby version, routes, controller inheritance, ApplicationController callbacks, authentication/authorization, parameter filtering, request/response formats, session/cookie configuration, exception handling, cache validators, download/streaming code, observability, and request tests before implementation;
- classify the boundary as request input, response contract, session/cookie state, callback lifecycle, content negotiation, conditional response, streaming/download, or controller exception handling;
- use the smallest supported strong-parameter API for the resolved Rails version; prefer params.expect where supported and locally adopted, otherwise use require plus permit;
- treat every request value, header, cookie, session-derived identifier, redirect target, and file name as untrusted until its owning boundary validates or authorizes it;
- never forward raw params into persistence or domain code; strong parameters are an input boundary, not authorization;
- keep controller response contracts explicit: status, format, body/rendering, headers, redirects, empty-body semantics, and error representation;
- remember that redirect_to does not terminate Ruby execution; return when continuing the method could produce side effects or another response;
- preserve Rails open-redirect protections and never enable cross-host redirects for untrusted input;
- keep session/cookie payloads minimal, treat signed versus encrypted storage deliberately, and never use session/cookie presence as the authorization source;
- keep controller callbacks narrow and action-scoped; use them for request prerequisites, not business workflows, transactions, or large orchestration graphs;
- define supported response formats explicitly and compose API wire contracts with rails-api-integration;
- use ETag/Last-Modified only when validator identity covers every representation dimension such as tenant, permission, locale, and other private variants;
- distinguish HTTP 304 transport behavior from application-state correctness and coordinate shared/private caching with rails-caching;
- authorize downloads before opening the source, bound producer/database work, and account for long-lived streams in request concurrency and runtime capacity;
- do not stream unbounded database/provider work directly from a controller without bounded production, timeout, disconnect, and cleanup semantics;
- use rescue_from only for expected errors with a stable HTTP contract and do not rescue StandardError broadly to hide programmer defects;
- coordinate error reporting with rails-observability rather than building one-controller global error handling;
- test status, content type, headers, redirect behavior, parameter rejection, authorization, callback scope, conditional 304 behavior, session/cookies, downloads, and expected/unexpected exception paths as applicable;
- never claim a controller contract is safe or performant without request-level evidence or focused regression tests.
