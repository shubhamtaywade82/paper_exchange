---
name: rails-authentication
description: Use when designing, implementing, reviewing, testing, or debugging Rails authentication, credentials, sessions, password recovery, login abuse controls, authentication context propagation, or browser/API identity boundaries.
---

# Rails Authentication Engineering

## Purpose

Treat authentication as a stateful security boundary with explicit identity proof, credential handling, session/token lifecycle, recovery, revocation, abuse controls, observable failure semantics, and deterministic verification.

Authentication answers:

> Who is this requester, and what authenticated state does the application recognize for this request?

Authorization answers a different question:

> May that authenticated actor perform this action on this resource?

Keep those contracts separate.

Core flow:

~~~text
repository mechanism
-> identity/credential boundary
-> authentication attempt
-> authenticated state
-> session/token lifecycle
-> request context propagation
-> protected resource boundary
-> logout/revocation/recovery
-> abuse detection
-> audit/observability
-> deterministic verification
~~~

## Activate when

- adding sign-in, sign-out, or authentication middleware;
- introducing or changing Rails generated authentication;
- reviewing or customizing the Rails authentication system generator output;
- reviewing Devise or another authentication gem;
- changing password hashing or credential storage;
- changing session creation, renewal, rotation, expiry, or invalidation;
- implementing password reset or credential recovery;
- adding remember-me or persistent login behavior;
- adding API tokens, bearer credentials, signed credentials, or service identities;
- changing browser/session authentication versus API authentication;
- supporting multiple devices or active-session management;
- adding account lockout, throttling, or login-abuse controls;
- propagating authenticated identity into jobs, mailers, Action Cable, or service boundaries;
- debugging unexpected login/logout state;
- responding to session compromise or credential compromise;
- reviewing authentication security regressions.

Do not activate merely because an endpoint has an Authorization header if the task is only outbound HTTP authentication; use the relevant integration skill.

## Repository inspection

Before changing authentication, identify:

1. Ruby and Rails versions;
2. the actual authentication mechanism: Rails generator, Devise, custom code, OAuth/OIDC provider, API token layer, or a combination;
3. User/account/identity/session/credential models;
4. password hashing and credential storage;
5. authentication concern/module/middleware;
6. session store and cookie configuration;
7. token/session tables, digests, expiration fields, and indexes;
8. routes/controllers/concerns used for sign-in and sign-out;
9. password reset/recovery models, tokens, mailers, and jobs;
10. remember-me/persistent-login behavior;
11. current-user/request context implementation;
12. browser CSRF policy and same-site cookie settings;
13. API authentication scheme and endpoint classification;
14. login throttling, lockout, device/session limits, or bot controls;
15. authorization/policy layer and protected-resource lookup conventions;
16. background jobs, mailers, Action Cable connections, webhooks, and service boundaries that may need identity context;
17. logging, audit events, metrics, security alerts, and credential filtering;
18. test helpers, request tests, system tests, factories/fixtures, and security regression coverage.

Do not infer authentication behavior from routes alone. Find where identity is actually established and where it is invalidated.

## Authentication mechanism boundary

Classify the repository mechanism before editing.

### Rails 8+ generated authentication

Rails 8 introduced a built-in authentication generator. The current Rails Security Guide documents a baseline flow containing User, Session, Current, SessionsController, PasswordsController, an Authentication concern, password reset views/mailers, routes, and migrations.

The generator uses has_secure_password/bcrypt for password hashing and creates a database-backed Session model in its baseline implementation.

Do not treat generated authentication as a black box. Inspect the generated concern, session model, routes, password reset flow, and migrations before modifying it.

### Authentication gem

For Devise or another gem, map:

~~~text
gem module
-> model concerns
-> controllers/routes
-> session/token storage
-> callbacks/hooks
-> configuration
-> upgrade/version semantics
~~~

Do not duplicate framework behavior with a second home-grown authentication concern.

### Custom authentication

For custom systems identify:

- password hashing API;
- credential comparison;
- session/token issuance;
- storage;
- revocation;
- expiry;
- recovery;
- request identity loading;
- audit/observability;
- failure semantics.

Custom authentication needs explicit security regression coverage because framework guarantees may not exist.

## Identity versus authorization

Authentication should establish a stable principal such as current_user, current_account, a service identity, or an API client identity.

Do not infer authorization from identity alone.

A protected request should normally compose:

~~~text
authenticate
-> resolve principal
-> resolve authoritative tenant/resource
-> authorize action
-> execute
~~~

Avoid trusting a client-supplied resource or tenant identifier as authoritative identity context.

Use the repository's authorization policy and tenant-isolation skills for resource access decisions.

## Credential storage

Passwords must never be stored in plaintext.

Inspect hashing algorithm/library, digest columns, credential normalization, password-change timestamp, password history requirements, compromised-password checks, logging filters, and migration compatibility.

For Rails has_secure_password, inspect the actual Rails version's supported behavior rather than assuming every version has identical validation or token APIs.

Password policy is separate from password hashing.

Never log plaintext passwords, password confirmations, reset tokens, bearer credentials, session cookies, or Authorization headers.

## Authentication state machine

Model authentication as explicit state transitions.

~~~text
anonymous
-> credential submitted
-> credential accepted/rejected
-> authenticated session created
-> authenticated request context
-> logout/revocation/expiry
-> anonymous
~~~

Recovery adds:

~~~text
authenticated
-> credential-change request
-> recovery verification
-> credential updated
-> previous authentication state reviewed/revoked
~~~

Compromise remediation may require:

~~~text
active sessions
-> revoke all
-> rotate/reissue credentials
-> re-authenticate
~~~

Define these transitions before adding callbacks or scattered controller logic.

## Session lifecycle

For browser authentication define:

- session creation;
- session renewal/rotation;
- expiry;
- inactivity timeout if required;
- absolute lifetime if required;
- logout invalidation;
- credential-change invalidation;
- global session revocation;
- multi-device semantics.

Rails security guidance explicitly treats session fixation, session hijacking, CookieStore replay, session expiry, and secret rotation as authentication/security concerns.

A successful login must not preserve attacker-controlled pre-authentication session state.

Use reset_session or the authentication framework's equivalent when the framework contract requires session renewal after authentication.

## Session fixation and rotation

Session fixation is distinct from session theft.

The critical invariant is:

> Successful authentication establishes a fresh authenticated session context that is not attacker-controlled.

Review pre-login session identifiers, the login transition, session renewal, old-session invalidation, remember-me behavior, and browser/proxy behavior.

Test the transition, not only the final authenticated page.

## Session revocation

Define the revocation source of truth.

Possible mechanisms include database-backed session deletion, session version/timestamp checks, credential-version checks, token denylists, or short-lived credentials with refresh-token rotation.

For multi-device systems distinguish:

- revoke current session;
- revoke one device;
- revoke all sessions;
- revoke on password change;
- revoke on suspected compromise.

Make revocation race behavior explicit. Security-sensitive operations may require a stronger freshness check than ordinary requests.

## Cookie and browser session contract

Review Secure, HttpOnly, SameSite, domain/path scope, expiry, and environment differences.

Rails CookieStore is encrypted/signed, but sensitive or highly mutable business state should not be placed in a client-side session merely because the cookie is protected.

Respect cookie size limits.

Keep secret_key_base and related secrets outside source control and use the repository's secrets mechanism.

Understand that rotating authentication secrets can invalidate existing encrypted/signed session material.

## Password reset and recovery

Treat password reset as an authentication protocol, not ordinary CRUD.

Define:

1. reset request;
2. account lookup behavior;
3. enumeration-safe response;
4. token generation/storage;
5. token lifetime;
6. one-time-use semantics;
7. trusted delivery;
8. token consumption;
9. credential update;
10. session/token revocation after successful reset;
11. notification/audit;
12. abuse/rate limiting.

Reset tokens must not be logged or exposed through analytics, referrers, screenshots, or generic error reporting.

A password reset should not silently leave known-compromised sessions active unless that behavior is an explicit security decision.

## Login abuse controls

Authentication endpoints are public security boundaries.

Assess credential stuffing, password spraying, brute-force attempts, account enumeration, reset-email abuse, token replay, bot traffic, and distributed attacks.

Possible controls include rate limiting, progressive backoff, device/IP controls, challenges, generic failure messages, anomaly detection, notifications, and safe recovery.

Avoid permanent lockouts that become denial-of-service primitives unless explicitly justified.

Rate limits should reflect the threat model; one global IP limit is rarely sufficient.

## Remember-me and persistent login

Persistent authentication changes the threat model.

Document token format/storage, lifetime, rotation, revocation, device scope, logout behavior, credential-change behavior, and stolen-token response.

Do not place a long-lived bearer credential into an opaque cookie without a revocation and rotation model.

## Browser authentication versus API authentication

Classify endpoints before changing authentication.

| Boundary | Typical credential | Key concerns |
|---|---|---|
| Browser HTML | session cookie | CSRF, cookie attributes, fixation, logout |
| Browser JSON | session cookie | CSRF and response contract |
| First-party API | bearer/session/token | leakage, expiry, revocation |
| Third-party API | API key/OAuth token | provider boundary and rotation |
| Service-to-service | service credential | workload identity, scope, rotation |

Do not blindly reuse browser session semantics for machine clients.

Do not disable CSRF protections simply because an endpoint returns JSON; classify the authentication boundary first.

## Authentication context propagation

Authenticated context can cross controllers, service objects, jobs, mailers, Action Cable, events, and downstream services.

Separate user actor attribution, tenant attribution, authorization context, credential material, and correlation identifiers.

Never serialize passwords, session cookies, bearer tokens, reset tokens, or live authentication objects into jobs/events.

A background job should not silently impersonate a live browser session.

If a job performs an authorization-sensitive action, pass stable actor identity and re-evaluate authorization against current state where required.

## Authentication callbacks and hooks

Callbacks can be useful for narrow lifecycle hooks but dangerous when they hide security state transitions.

Prefer explicit ownership for session issuance, credential change, session revocation, recovery, and audit events.

If callbacks are used, document trigger, ordering, transaction semantics, failure behavior, and bypass paths.

Do not make credential security depend on a model callback if bulk SQL or alternate writers can bypass it.

## Failure contracts

Define behavior for missing credentials, malformed credentials, wrong credentials, disabled/suspended users, expired sessions, revoked sessions, expired/reset tokens, consumed reset tokens, rate-limited login, unauthorized authenticated requests, and stale authentication context.

Keep responses safe against account enumeration.

Do not conflate unauthenticated, forbidden, and deliberately hidden resource responses; use repository-specific HTTP/error conventions.

## Security-sensitive operations

Some actions should require recent or fresh authentication even if a session exists.

Examples include password changes, MFA/security settings, API-key rotation, payout/payment destination changes, account deletion, and privilege changes.

Define a freshness requirement rather than assuming logged in is equivalent to recently authenticated.

Enforce freshness on the server.

## Observability and audit

Authentication telemetry should support incident response without leaking secrets.

Useful events include login success/failure category, logout, session creation/revocation, reset requested/completed/failed, credential change, global revocation, and suspicious activity.

Keep dimensions bounded and safe.

Never log raw passwords, session cookies, bearer tokens, reset tokens, or Authorization headers.

Compose with rails-observability and rails-incident-engineering.

## Testing strategy

Authentication requires transition-focused tests.

### Credential verification

- valid credentials;
- invalid credentials;
- unknown account;
- disabled/suspended account;
- credential normalization.

### Session lifecycle

- anonymous request rejected;
- successful login creates authenticated state;
- authenticated request resolves expected principal;
- logout invalidates the session;
- expiry/revocation rejects stale state;
- session rotation occurs at the correct transition.

### Recovery

- reset request;
- enumeration-safe response;
- valid token;
- expired token;
- consumed token;
- invalid token;
- credential update;
- post-reset revocation behavior.

### Abuse

- rate-limit behavior;
- lockout/challenge behavior if present;
- repeated failures do not expose account existence.

### Boundary separation

- authentication does not bypass authorization;
- alternate endpoints/jobs cannot skip required authentication context;
- browser and API auth contracts remain distinct.

Prefer deterministic request/system tests and fake external mail/provider delivery at the narrow boundary.

## Performance and capacity

Authentication can become a database and cryptographic hotspot.

Measure password hashing cost, login throughput, session lookup rate, session-table growth, reset-token queries, rate-limit storage, and authentication cache/store latency.

Do not reduce password hashing cost solely to improve latency without security review.

Use indexes for session/token lookup paths.

Avoid loading entire user graphs during every request authentication.

## Multi-device session management

If users can be signed in on multiple devices, define session ownership, device metadata, last activity, session listing, per-device revoke, revoke-all, and expiry.

Treat device/session metadata as security-sensitive and minimize stored values.

## Compromise response

Plan for leaked passwords, session cookies, reset tokens, API tokens, signing secrets, and credential-store exposure.

For each credential class define detection, revocation, rotation, session invalidation, notification, audit evidence, and recovery verification.

Do not assume changing the password invalidates every other credential type.

## Anti-patterns / failure modes

- authentication treated as authorization;
- duplicate custom authentication beside an existing framework;
- plaintext passwords;
- credentials in logs;
- reset tokens in logs/analytics without controls;
- pre-authentication session reused after login;
- logout that only clears UI state;
- password reset that leaves compromised sessions active without an explicit rationale;
- bearer token with no revocation or expiry model;
- browser session reused as a generic service credential;
- client-supplied tenant used as authoritative identity context;
- account enumeration through inconsistent login/reset responses;
- permanent lockout as the only brute-force control;
- authentication callbacks relied on by bypassable persistence paths;
- live external provider dependencies in every CI authentication test;
- raw session IDs/tokens used as metric labels.

## Reference example

Session creation with the full fixation defense: reset_session on privilege change, constant responses, and status codes that match the outcome.

```ruby
class User < ApplicationRecord
  has_secure_password # password_digest + authenticate
end

class SessionsController < ApplicationController
  def create
    user = User.find_by(email: session_params[:email])

    if user&.authenticate(session_params[:password])
      reset_session                  # rotate the session identifier on login (fixation defense)
      session[:user_id] = user.id
      redirect_to root_url, notice: t(".signed_in")
    else
      flash.now[:alert] = t(".invalid") # identical message for unknown email and bad password
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_url
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end
```

## Agent review checklist

- [ ] Ruby/Rails version resolved
- [ ] actual authentication mechanism identified
- [ ] identity boundary documented
- [ ] authentication/authorization distinction preserved
- [ ] credential hashing/storage inspected
- [ ] session lifecycle documented
- [ ] session fixation defense verified
- [ ] logout/revocation semantics explicit
- [ ] cookie attributes reviewed for browser auth
- [ ] password recovery lifecycle explicit
- [ ] account-enumeration behavior reviewed
- [ ] login/reset abuse controls reviewed
- [ ] remember-me semantics explicit if present
- [ ] browser/API authentication boundaries separated
- [ ] authentication context propagation explicit
- [ ] callback/bypass paths audited
- [ ] sensitive-operation freshness requirements reviewed
- [ ] safe authentication telemetry defined
- [ ] deterministic transition tests exist
- [ ] alternate auth paths/jobs/channels reviewed
- [ ] performance/capacity evidence collected when material
- [ ] compromise/revocation path exists

## Verification

For a new authentication capability:

~~~text
identify mechanism
-> model principal and state transitions
-> inspect credential/session storage
-> define login/logout/recovery contracts
-> define revocation
-> define browser/API boundary
-> add abuse/security controls
-> add transition-focused tests
-> run repository security tooling
-> run full validation
~~~

Do not claim authentication security merely because a framework helper exists. Verify the actual repository path.

## Rails 8 current framework considerations

- Rails 8 includes an authentication system generator that establishes a session-based, password-resettable starting point.
- Generated authentication is scaffolding, not a proof of repository-specific security correctness; reconcile it with the application's session, authorization, recovery, abuse-control, and observability contracts.

## Source foundation

Primary current Rails guidance:

- https://guides.rubyonrails.org/security.html
- https://guides.rubyonrails.org/8_0_release_notes.html
- https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html
- https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection.html

The current Rails Security Guide documents the Rails 8+ authentication generator, password reset flow, has_secure_password, session storage, session fixation, session expiry, CSRF, brute-force/account-hijacking guidance, and secret rotation.

Repository composition:

- skills/rails-security/SKILL.md
- skills/rails-security-engineering/SKILL.md
- skills/rails-action-controller/SKILL.md
- skills/rails-api-integration/SKILL.md
- skills/rails-observability/SKILL.md
- skills/rails-incident-engineering/SKILL.md
- skills/rails-active-record/SKILL.md
- skills/rails-database-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md

## Authentication state machine

Treat authentication as explicit states and transitions rather than a boolean current-user check:

anonymous
  -> credential_verified
  -> authenticated
  -> renewed
  -> expired
  -> revoked

Also model security-triggered transitions:

authenticated
  -> logout
  -> credential_change
  -> global_revoke
  -> compromise_response

For each transition identify the authoritative state store, the credential involved, the evidence required, and what subsequent requests must observe.

A valid session is not necessarily a fresh authentication. Sensitive operations may require recent credential proof or explicit reauthentication.

## Session lifecycle

Define the complete lifecycle:

- anonymous request;
- session creation;
- successful-login renewal;
- request-time principal resolution;
- inactivity expiry;
- absolute/session-age expiry where required;
- logout;
- current-session revocation;
- per-device revocation;
- global revocation;
- password-change/reset effects;
- compromise response.

Do not equate clearing browser state with server-side logout. The repository's authentication authority must be invalidated according to its session model.

Rails documents CookieStore as encrypted by default, but session data remains client-side and is constrained by cookie size and replay/security considerations. Keep only appropriate session state in the cookie and store durable business state server-side.

## Multi-device session management

When sessions are persisted server-side, model device/session ownership explicitly:

user
  ├─ session A / device A
  ├─ session B / device B
  └─ session C / device C

Define whether the application supports:

- revoke current device;
- revoke one device;
- revoke all devices;
- password-change invalidation;
- compromise-triggered global revocation;
- device/session visibility.

User-agent and IP information may be useful context and audit metadata, but should not silently become a strong identity proof.

## Compromise response

Authentication design must include an emergency response path:

1. identify affected credential classes;
2. revoke active sessions/tokens;
3. rotate compromised secrets;
4. require reauthentication where appropriate;
5. notify affected users according to policy;
6. retain non-secret audit evidence;
7. verify previously issued credentials fail;
8. document residual risk.

Do not assume password reset automatically revokes API tokens, remember-me credentials, or every device session unless the implementation explicitly guarantees it.

## Security-sensitive operations

Require recent authentication or explicit reauthentication when the repository's security contract demands it, including:

- password changes;
- API key/token rotation;
- MFA/security-setting changes;
- payment destination changes;
- account deletion;
- privilege changes.

Enforce this on the server. A frontend confirmation is not authentication evidence.

## Authentication context propagation

When an authenticated request crosses into a job, mailer, event, Action Cable action, or service:

- propagate stable actor/tenant identifiers only when needed;
- never serialize passwords, session cookies, bearer tokens, or reset credentials;
- re-resolve the principal at execution time;
- re-evaluate authorization at the destination boundary;
- define deleted/disabled principal behavior;
- preserve correlation identifiers separately from authentication material.

Actor attribution is not authorization. A background job carrying a user ID must still enforce the destination operation's authorization policy.

## Browser authentication versus API authentication

Classify each boundary explicitly:

- browser session/cookie authentication;
- API bearer/opaque-token authentication;
- service-to-service credentials;
- WebSocket connection authentication.

Do not disable CSRF globally to accommodate JSON requests. Determine whether the endpoint is cookie-authenticated, token-authenticated, or deliberately mixed, and give each credential class explicit expiry, revocation, and failure semantics.

## Failure contracts

Define and test the behavior for:

- missing credential;
- invalid credential;
- expired credential;
- revoked credential;
- disabled/deleted principal;
- invalid/expired/replayed password reset;
- throttled login;
- authenticated but unauthorized action.

Authentication failure and authorization failure are different contracts. Resource-not-found behavior may also be deliberately different where information disclosure is a concern.

## Observability and audit

Record security-relevant events without credential material:

- login success/failure;
- logout;
- session creation/revocation;
- password-reset request/completion/failure;
- credential change;
- global revoke;
- throttling/abuse events;
- reauthentication;
- compromise response.

Use structured, bounded dimensions. Never log passwords, raw tokens, reset credentials, session cookies, or full authorization headers.

## Performance and reliability

Authentication is a public, potentially expensive boundary. Review password-hash cost, login/reset rate, session-store latency, token lookup indexes, distributed throttling capacity, and dependency failure behavior.

Do not weaken password hashing or security controls to solve capacity problems. Measure first and preserve fail-safe authentication semantics.

## Testing strategy

Prefer deterministic transition-focused tests:

- valid login;
- invalid and missing credentials;
- protected request without identity;
- authenticated request;
- logout;
- expiry;
- revocation;
- session fixation transition;
- password reset valid/expired/replayed;
- post-reset revocation;
- remember-me issuance/expiry/revocation when supported;
- browser/API authentication and CSRF semantics;
- login/reset abuse thresholds;
- fresh/stale authentication for sensitive actions;
- actor propagation without credential serialization;
- multi-device revocation;
- compromise response.

Use fake clocks and repository-local transports where practical. Do not depend on live email providers or external identity providers for deterministic unit/request/system contracts.

## Source foundation

Primary source: Ruby on Rails, Securing Rails Applications. The current guide documents the Rails authentication generator, password reset, has_secure_password, authenticate_by, sessions, session fixation, session expiry, CSRF, brute-force/account-hijacking concerns, credentials, and related security controls.

https://guides.rubyonrails.org/security.html

The repository's reusable authentication patterns operationalize the source material:

- authentication-mechanism-boundary
- credential-storage-contract
- session-lifecycle-contract
- session-fixation-rotation
- session-revocation-contract
- password-recovery-contract
- login-abuse-controls
- remember-me-contract
- browser-api-auth-boundary
- authentication-context-propagation
- authentication-freshness-boundary

Use patterns only when their problem shape exists; they are decision aids rather than mandatory abstractions.

## Rails authentication changes

For authentication changes:
- resolve the Ruby/Rails version and identify the actual mechanism in use before implementation;
- inspect generated Rails authentication, Devise, custom concerns, middleware, session stores, token stores, and alternate authentication paths;
- keep authentication and authorization separate and preserve the repository's authoritative policy boundary;
- authentication and authorization remain separate contracts even when they share request/session plumbing;
- treat credential material, password reset tokens, session cookies, and bearer tokens as secrets that must not enter logs, jobs, events, or telemetry;
- model authentication as explicit state transitions: credential verification, session/token establishment, request context, logout, expiry, and revocation;
- verify session fixation resistance and fresh session state after successful login;
- define current-session, per-device, global revocation, password-change, and compromise semantics where applicable;
- treat password recovery as a bounded one-time/expiring authentication protocol with enumeration-safe responses;
- separate browser session authentication from API/service credentials and verify CSRF semantics rather than disabling protection broadly;
- propagate actor/tenant attribution without serializing live authentication credentials and re-evaluate authorization at asynchronous boundaries;
- require fresh authentication for security-sensitive credential/privilege changes when the product/security contract requires it;
- add deterministic tests for success and rejection paths, expiry, revocation, fixation, recovery replay, and abuse controls;
- run bin/validate and security tooling, and report only observed verification evidence.

## Authentication and authorization boundary

authentication and authorization remain separate concerns: authentication establishes identity and session state; authorization decides permitted actions within that context.
