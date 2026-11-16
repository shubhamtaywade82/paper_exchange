---
name: rails-action-mailbox
description: "Use when designing, implementing, reviewing, testing, or operating Rails Action Mailbox inbound email processing, ingress authentication, mailbox routing, message lifecycle, domain association, failure handling, retention, observability, and security."
---

# Rails Action Mailbox Engineering

## Purpose

Treat inbound email as an untrusted external ingestion boundary, not as a controller shortcut.

This skill owns Action Mailbox-specific decisions around:

- ingress and provider boundary;
- raw RFC822/MIME message handling;
- InboundEmail lifecycle;
- mailbox routing;
- mailbox processing and callbacks;
- sender/recipient and tenant association;
- duplicate and replay semantics;
- bounce, failure, quarantine, and recovery;
- retention/incineration;
- attachment interaction with Active Storage;
- deterministic testing.

It composes existing repository capabilities:

- rails-api-integration for provider/webhook and ingress boundary contracts;
- rails-security and rails-security-engineering for trust, authenticity, authorization, tenant isolation, and abuse controls;
- rails-active-job for asynchronous mailbox execution, retry, queue, idempotency, and transaction semantics;
- rails-active-storage for raw email storage and attachment lifecycle;
- rails-action-mailer for outbound replies and bounce notices;
- rails-observability for correlation, error reporting, metrics, and lifecycle telemetry;
- rails-reliability-engineering and rails-incident-engineering for overload, provider failure, backlog, quarantine, and operational recovery;
- rails-distributed-systems / rails-event-driven-messaging when inbound email becomes a cross-process workflow;
- rails-test-engineering for deterministic ingress/mailbox tests.

Official Rails documentation describes Action Mailbox as the inbound counterpart to Action Mailer. Incoming messages are accepted through a configured ingress, persisted as ActionMailbox::InboundEmail records with raw email in Active Storage, routed to controller-like mailboxes, and processed asynchronously through Active Job.

Core flow:

~~~
provider / MTA
-> authenticated ingress
-> raw RFC822/MIME capture
-> InboundEmail
-> routing
-> mailbox processing
-> domain transaction / side effects
-> delivered | bounced | failed
-> telemetry / recovery
-> retention / incineration
~~~

## Activate when

- adding ActionMailbox::Base or ApplicationMailbox;
- adding a mailbox with process or processing callbacks;
- configuring Mailgun, Mandrill, Postmark, SendGrid, Exim, Postfix, Qmail, or relay ingress;
- changing config.action_mailbox.ingress;
- handling inbound email from customers, replies, support addresses, aliases, or automated systems;
- mapping sender/recipient data to a user, tenant, ticket, project, or domain resource;
- handling email attachments or raw message storage;
- diagnosing duplicate, missing, delayed, bounced, failed, or misrouted inbound mail;
- changing incinerate_after or inbound-email retention;
- adding replay, quarantine, operator tooling, or forensic workflows;
- testing inbound email without live provider dependencies.

Do not activate for outbound email alone; route those tasks to rails-action-mailer.

## Repository inspection

Inspect:

1. resolved Rails, Active Job, and Action Mailbox versions;
2. queue adapter and worker configuration;
3. config.action_mailbox.ingress and credentials;
4. provider webhook/MTA configuration and reverse-proxy limits;
5. app/mailboxes/application_mailbox.rb and existing mailbox routes;
6. action_mailbox_inbound_emails schema and Active Storage configuration;
7. sender/recipient/tenant association and authorization rules;
8. existing idempotency, jobs, events, outbox/inbox, and Action Mailer behavior;
9. logging, error reporting, metrics, alerting, replay, and runbook conventions;
10. ActionMailbox::TestCase, fixtures, factories, and Active Storage test service.

Never invent an ingress contract before inspecting the actual provider/MTA setup.

## Ingress boundary

Classify the ingress before processing any message.

~~~
external provider / MTA
-> transport authentication
-> request normalization
-> raw message capture
-> InboundEmail persistence
-> asynchronous routing
~~~

Ingress authentication proves only that the request was accepted by the configured ingress mechanism. It does not prove:

- the sender is a registered user;
- the recipient belongs to a tenant;
- the message is business-authorized;
- the content is safe;
- the From header is trustworthy as identity.

For each ingress define:

- endpoint/path;
- provider/MTA authentication mechanism;
- credential owner and rotation;
- raw message requirement;
- request/body size limits;
- timeout and proxy limits;
- replay behavior;
- logging/filtering;
- failure response semantics.

Keep provider credentials out of mailbox/domain code.

## Mailbox routing

Action Mailbox routes incoming email to mailbox classes using configured routes. Routing matches recipient-related fields and invokes the selected mailbox asynchronously.

Design routing as an explicit contract:

~~~
normalized recipient
-> specific route
-> mailbox
-> domain owner
~~~

Rules:

- order routes from specific to general;
- keep patterns narrow and readable;
- normalize address expectations before matching when custom normalization exists;
- define a deliberate catch-all/backstop strategy;
- do not route authorization decisions solely from a string match;
- do not place tenant identity in an unauthenticated mailbox name and treat it as authorization;
- test collisions between routes;
- test unmatched recipients and explicit bounce behavior.

## Mailbox processing boundary

A mailbox should behave like an application boundary, not a miniature controller.

Typical flow:

~~~
InboundEmail
-> parse mailbox
-> validate sender/recipient context
-> resolve domain owner
-> authorize operation
-> perform bounded domain change
-> enqueue follow-up work after durable state is established
~~~

Use inbound_email.mail for parsed email data and inbound_email.source only when raw RFC822 content is specifically required.

Keep the mailbox responsible for orchestration, not unrelated domain policy.

Prefer:

- small mailbox classes;
- domain services/policies for complex rules;
- transaction boundaries at the authoritative data owner;
- explicit failure classifications;
- idempotent domain side effects.

Avoid:

- large parsing libraries embedded in every mailbox;
- direct cross-tenant writes;
- network calls hidden in callbacks;
- unbounded loops over attachments;
- irreversible side effects before duplicate detection.

## Lifecycle and processing states

Rails tracks inbound processing through:

- pending;
- processing;
- delivered;
- failed;
- bounced.

Processed states are delivered, failed, and bounced, after which the inbound record is scheduled for incineration.

Treat those framework states as operational evidence, not as a complete business state machine.

If the product needs states such as accepted, classified, linked, imported, rejected, quarantined, or replayed, store them in the domain model or an explicit processing record.

Do not overload Action Mailbox status with unrelated business state.

## Callbacks and failure semantics

Use before_processing for cheap, deterministic prerequisites that should prevent process.

Use process for the actual mailbox operation.

Use after_processing for bounded lifecycle work that is safe after the main operation.

Use around_processing only when a cross-cutting boundary genuinely needs wrapping semantics.

Rails supports bounce_with, bounce_now_with, bounced!, and rescue_from for mailbox-specific failure handling. bounce_with marks the inbound email bounced and enqueues the outbound message; bounce_now_with delivers immediately.

Classify failures:

| Failure | Typical handling |
|---|---|
| malformed/unsupported input | reject or quarantine |
| sender not eligible | bounce/reject |
| recipient not routable | backstop or bounce |
| authorization failure | reject; never mutate protected state |
| transient provider/domain dependency | bounded retry |
| duplicate business message | acknowledge as already handled |
| poison message | quarantine and alert |
| programmer defect | fail and surface through observability |

Never use a broad rescue that turns programmer defects into successful delivery.

## Authenticity and security

Treat inbound email as hostile input.

Separate these questions:

~~~
Was the ingress request authenticated?
Was the provider message authentic?
Is the claimed sender eligible?
Is the recipient authorized?
Is this operation allowed for this tenant/resource?
Is the content safe to parse/store/render?
~~~

Review:

- ingress authentication;
- SPF/DKIM/DMARC evidence when product policy requires it;
- provider signature/token validation;
- sender normalization;
- recipient/alias authorization;
- tenant isolation;
- header injection;
- HTML content;
- URL schemes;
- attachments;
- archive/privacy policy;
- secrets and credentials in message content;
- log redaction.

Do not trust From, Reply-To, Return-Path, or arbitrary headers as authentication merely because they parse successfully.

If sender identity is required for authorization, define the authoritative identity proof explicitly.

Never log full raw email bodies by default.

## Idempotency and duplicate delivery

Inbound email can be repeated by providers, retries, users, forwards, or operational replay.

Do not assume one InboundEmail row means the business effect has happened exactly once.

Define a domain idempotency key where duplicate effects matter. Preferred evidence can include:

- stable Message-ID;
- provider event/message identifier;
- repository-owned ingestion identifier;
- domain-specific immutable fingerprint when no stable identifier exists.

Store the idempotency decision at the same durable owner as the business side effect.

~~~
inbound evidence
-> idempotency lookup/constraint
-> domain transaction
-> durable result
~~~

For replay:

- preserve original message identity;
- record replay attempt/operator context;
- prevent replay from bypassing authorization;
- make duplicate handling deterministic.

Compose with patterns/rails/inbox-deduplication.md for asynchronous-consumer-like workflows.

## Tenant and resource association

Resolve the domain owner through authoritative application state.

Examples:

- recipient alias -> tenant;
- verified sender -> user;
- reply token/address -> thread;
- mailbox alias -> project.

Do not derive authorization solely from:

- mailbox class name;
- recipient local-part;
- arbitrary custom header;
- message body;
- signed-looking but unverified token.

For multi-tenant systems:

1. resolve tenant;
2. verify sender/operation within that tenant;
3. authorize the target resource;
4. perform the mutation under that tenant boundary;
5. test cross-tenant rejection.

Keep tenant identity explicit in downstream jobs/events created from inbound mail.

## Attachments and Active Storage

Action Mailbox stores the original email source through Active Storage, and parsed mail can include attachments.

Compose with rails-active-storage for storage, access, processing, purge, and deterministic test behavior.

For business attachments define:

- allowed types;
- maximum size/count;
- malware/content scanning requirements;
- tenant ownership;
- retention;
- synchronous versus asynchronous extraction;
- failure behavior;
- purge lifecycle.

Avoid downloading every attachment into memory in the mailbox process.

## Transactions and asynchronous work

Use the authoritative domain transaction for business invariants.

~~~
validate / authorize
-> transaction
   -> domain state
   -> durable outbox or transactional enqueue
-> commit
-> async follow-up
~~~

Do not enqueue work that assumes a database record exists before it is durably committed unless the queue semantics explicitly provide the required guarantee.

Do not make external network calls inside a database transaction unless the transaction contract truly requires it and latency/failure behavior is bounded.

Coordinate with rails-active-job, rails-database-engineering, and rails-event-driven-messaging.

## Retention, privacy, and incineration

Rails schedules processed inbound emails for automatic incineration; the documented default is 30 days via config.action_mailbox.incinerate_after.

Treat retention as a privacy/data-governance decision.

Define:

- required forensic/debug window;
- legal/compliance retention;
- sensitive-content handling;
- tenant/account deletion behavior;
- raw email retention;
- derived domain data retention;
- attachment retention;
- replay window;
- purge verification.

Do not extend raw-message retention merely because debugging is convenient.

Do not assume incinerating InboundEmail also deletes every domain record or derived attachment created by your mailbox.

## Observability and operations

Record low-cardinality lifecycle telemetry such as provider, mailbox class, route, outcome, processing duration, retry count, attachment count/size bucket, queue age, and quarantine count.

Preserve correlation/causation identifiers across:

~~~
ingress request
-> InboundEmail
-> mailbox
-> domain transaction
-> job/event
-> outbound reply
~~~

Do not emit raw email body, full MIME source, credentials, authorization headers, or sensitive attachment contents.

Distinguish ingress rejection, routing failure, mailbox failure, queue backlog, dependency failure, duplicate/replay volume, and quarantine volume.

## Capacity and performance

Measure:

- ingress request rate;
- MIME payload size;
- parsing CPU;
- attachment count/size;
- mailbox processing latency;
- Active Job queue age;
- database writes;
- Active Storage bandwidth;
- downstream dependency calls.

Bound body size, attachment count/size, parser work, per-message network calls, job concurrency, and retry frequency.

Do not increase mailbox worker concurrency without checking database, storage, CPU, and downstream capacity.

## Provider and MTA compatibility

Treat each ingress as an adapter boundary.

Document:

- provider endpoint;
- authentication;
- raw message format;
- signature validation;
- maximum payload;
- retry behavior;
- duplicate behavior;
- timeout/response expectations;
- deployment rotation procedure.

Keep provider-specific parameters at the ingress boundary. The mailbox should consume InboundEmail rather than provider-specific request shapes.

## Local development and testing

Use ActionMailbox::TestHelper for deterministic inbound email construction and routing. Test helpers support fixtures, Mail options, and raw RFC822 source creation.

Test at the smallest owning boundary:

- ingress authentication contract;
- route selection;
- unmatched route behavior;
- mailbox processing;
- sender/resource authorization;
- tenant isolation;
- duplicate/idempotency behavior;
- bounce behavior;
- transient failure/retry;
- poison-message quarantine;
- attachment limits and storage;
- domain transaction boundaries;
- job enqueue semantics;
- retention/incineration policy;
- observability/redaction.

Ordinary CI should use deterministic local adapters/storage and fake provider boundaries.

Do not use a live email provider to prove ordinary mailbox business logic.

## Reference example

A mailbox that authenticates the sender before processing, creates its record, and hands attachments to Active Storage.

```ruby
class SupportMailbox < ApplicationMailbox
  routing /^support\+/i => :support

  before_processing :ensure_known_sender

  def process
    ticket = current_account.tickets.create!(
      subject: mail.subject,
      from_address: mail.from.address
    )

    mail.attachments.each do |attachment|
      ticket.attachments.attach(
        io: attachment.body.to_io,
        filename: attachment.filename,
        content_type: attachment.mime_type
      )
    end
  end

  private

  def ensure_known_sender
    bounce_with Mailer.unrecognized_sender(mail) unless mail.from.address.end_with?("@example.com")
  end
end
```

## Agent review checklist

- [ ] Rails/Action Mailbox version resolved
- [ ] ingress/provider/MTA boundary inspected
- [ ] ingress authentication mechanism explicit
- [ ] raw RFC822 requirement explicit
- [ ] request/body size limits reviewed
- [ ] ApplicationMailbox routing order reviewed
- [ ] catch-all/unmatched recipient behavior explicit
- [ ] mailbox owns orchestration rather than unrelated domain policy
- [ ] sender identity proof separated from ingress authentication
- [ ] recipient and tenant authorization explicit
- [ ] duplicate/replay semantics explicit
- [ ] domain idempotency owner explicit
- [ ] transaction/commit boundary explicit
- [ ] downstream job/event semantics explicit
- [ ] attachments reviewed through Active Storage
- [ ] content/file limits explicit
- [ ] failure/bounce/quarantine behavior explicit
- [ ] status transitions treated as lifecycle evidence
- [ ] retention/incineration policy reviewed
- [ ] logs redact raw message and credentials
- [ ] lifecycle telemetry and correlation reviewed
- [ ] deterministic mailbox tests exist
- [ ] cross-tenant and duplicate negative tests exist

## Anti-patterns / failure modes

- trusting the From header as authentication;
- treating ingress authentication as domain authorization;
- using recipient strings as tenant authorization;
- routing broad patterns before specific mailbox routes;
- silently dropping unmatched recipients;
- performing non-idempotent side effects before duplicate detection;
- assuming Action Mailbox guarantees exactly-once business effects;
- rescuing all exceptions and marking mail delivered;
- doing unbounded work from email attachments;
- logging raw RFC822 content;
- exposing internal InboundEmail records as a public API;
- putting provider-specific payload parsing in mailbox classes;
- extending raw-email retention without a privacy requirement;
- assuming incineration removes derived domain data;
- performing slow network calls inside database transactions;
- enqueueing follow-up jobs before required state is committed;
- relying on Message-ID alone when provider behavior does not guarantee stability;
- using replay tooling that bypasses authorization;
- treating HTML or attachment MIME metadata as trusted;
- claiming inbound email is secure because the provider signed the webhook.

## Verification

For an Action Mailbox feature:

~~~
Rails/version evidence
-> ingress boundary
-> authentication
-> routing
-> sender/recipient/tenant authorization
-> idempotency
-> domain transaction
-> async follow-up
-> failure/bounce/quarantine
-> attachment/security review
-> retention
-> observability
-> deterministic tests
-> regression verification
~~~

Never claim that inbound email is exactly-once, authenticated as a business user, or durable beyond configured retention without evidence from the actual ingress, domain, queue, and storage contracts.

## Source foundation

Primary Rails sources:

- https://guides.rubyonrails.org/action_mailbox_basics.html
- https://api.rubyonrails.org/classes/ActionMailbox/Base.html
- https://api.rubyonrails.org/classes/ActionMailbox/Router.html
- https://api.rubyonrails.org/classes/ActionMailbox/InboundEmail.html
- https://api.rubyonrails.org/classes/ActionMailbox/TestHelper.html

These sources document Action Mailbox ingress configuration, asynchronous mailbox routing, InboundEmail persistence/status tracking, mailbox callbacks/bounce behavior, testing helpers, and automatic incineration.

Composed repository skills:

- skills/rails-action-mailer/SKILL.md
- skills/rails-active-job/SKILL.md
- skills/rails-active-storage/SKILL.md
- skills/rails-api-integration/SKILL.md
- skills/rails-security/SKILL.md
- skills/rails-security-engineering/SKILL.md
- skills/rails-database-engineering/SKILL.md
- skills/rails-event-driven-messaging/SKILL.md
- skills/rails-distributed-systems/SKILL.md
- skills/rails-observability/SKILL.md
- skills/rails-reliability-engineering/SKILL.md
- skills/rails-incident-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md

## Rails Action Mailbox changes

For inbound email and Action Mailbox changes:
- inspect the configured ingress, provider/MTA setup, ApplicationMailbox routes, mailbox classes, Active Job queue behavior, InboundEmail schema/storage, authorization rules, Active Storage behavior, retention configuration, observability, and mailbox tests before implementing;
- classify the boundary as external ingress, mailbox routing, mailbox processing, or downstream asynchronous work;
- keep ingress authentication separate from sender identity, recipient authorization, and tenant/resource authorization;
- treat the From header, Reply-To, Return-Path, custom headers, HTML, links, and attachment metadata as untrusted input until the owning boundary verifies them;
- define provider/MTA retry, duplicate, raw-message, body-size, timeout, and credential-rotation contracts at the ingress boundary;
- keep provider-specific payload handling out of mailbox/domain code;
- order mailbox routes from specific to general, define unmatched-message behavior, and test route collisions;
- keep mailbox classes focused on orchestration and delegate complex domain rules to the owning service/model/policy boundary;
- use before_processing for cheap deterministic prerequisites and keep framework status truthful; do not convert programmer defects into successful delivery;
- separate business-invalid messages, transient dependencies, poison messages, and programmer failures so retry/bounce/quarantine behavior is bounded and explicit;
- do not assume Action Mailbox provides exactly-once business effects; define durable domain idempotency for non-idempotent mutations and preserve message identity during replay;
- persist tenant/resource ownership through authoritative application state and propagate tenant context to downstream jobs/events;
- coordinate business mutations and follow-up jobs/events through the actual transaction/commit contract;
- use rails-active-storage for attachment/storage lifecycle and enforce server-side size/type/content limits;
- treat raw inbound mail as privacy-sensitive data; never log full raw messages or credentials by default;
- review config.action_mailbox.incinerate_after as a raw-message retention policy and distinguish it from lifecycle of derived domain data;
- use deterministic ActionMailbox test helpers and local/test storage/provider doubles; do not rely on live email providers for ordinary CI;
- add negative tests for spoofed senders, cross-tenant targets, duplicate delivery, unmatched routing, poison messages, and sensitive log output;
- never claim inbound email is authenticated as a business user merely because the ingress is authenticated, and never claim exactly-once processing without evidence from the domain idempotency contract.
