---
name: rails-action-cable
description: "Use when designing, implementing, reviewing, testing, or operating Rails Action Cable/WebSocket connections, channels, subscriptions, streams, broadcasting, authorization, reconnect behavior, pub/sub adapters, realtime capacity, or cable security."
---

# Rails Action Cable & Realtime Engineering

## Purpose

Treat Action Cable as a realtime distributed boundary rather than another controller endpoint.

Action Cable introduces long-lived WebSocket connections, channel subscriptions, pub/sub broadcastings, client reconnect behavior, and a separate runtime/capacity profile from ordinary request-response Rails.

Core flow:

```text
connection authentication
-> subscription authorization
-> explicit channel identity
-> bounded stream
-> domain event/state change
-> broadcast contract
-> client delivery
-> reconnect/resubscribe
-> observable lifecycle
```

Rails documents Action Cable around connections, consumers, channels, subscriptions, streams, and broadcastings. Broadcastings are online/time-dependent rather than durable message queues; clients that are not subscribed when a broadcast is emitted do not receive that past broadcast.

## Activate when
- configuring or reviewing Solid Cable as the Action Cable pub/sub backend

- adding or changing `ApplicationCable::Connection`;
- adding or changing an Action Cable channel;
- implementing `subscribed`, `unsubscribed`, or channel actions;
- adding `stream_from`, `stream_for`, or `broadcast_to`;
- exposing realtime notifications, dashboards, collaboration, chat, presence, or live status;
- changing WebSocket authentication or authorization;
- configuring Action Cable adapters or Redis/pub/sub;
- diagnosing dropped connections, duplicate subscriptions, missed broadcasts, or reconnect storms;
- changing Action Cable deployment/process capacity;
- reviewing channel parameters, tenant isolation, or client-controlled stream names;
- testing Action Cable subscriptions/broadcasts;
- deciding whether data belongs in durable messaging instead of realtime delivery.

Do not activate merely because a normal controller emits JSON. Use `rails-api-integration` or ordinary Rails request skills unless a WebSocket/realtime boundary exists.

## Repository inspection

Inspect before changing realtime behavior:

1. Ruby/Rails version and Action Cable APIs available in that version;
2. `ApplicationCable::Connection` and connection identifiers;
3. `ApplicationCable::Channel` and existing channel hierarchy;
4. channel subscription parameters and authorization conventions;
5. current_user/current_account/tenant resolution;
6. cookie/session/token authentication used by WebSockets;
7. Action Cable URL, allowed origins, mount path, and environment configuration;
8. subscription adapter and Redis/pub/sub topology;
9. stream naming and `stream_from` / `stream_for` usage;
10. broadcast producers and event/state ownership;
11. client-side consumers/subscriptions and reconnect behavior;
12. queue/job/event sources that trigger broadcasts;
13. deployment process model, worker/web concurrency, memory, and Redis capacity;
14. logging, metrics, connection lifecycle telemetry, and incident diagnostics;
15. existing channel/system/integration tests;
16. fallback behavior when realtime delivery is unavailable.

Do not introduce a parallel realtime framework or custom WebSocket transport without repository evidence that Action Cable cannot satisfy the contract.

## Connection authentication

Connection authentication establishes who owns a WebSocket connection.

The connection layer should answer:

- who is the caller?
- which account/tenant context is loaded?
- which connection identifiers are safe to expose to channel callbacks?
- what makes a connection unauthorized?
- how is authentication failure surfaced?
- how are credentials rotated or revoked?

Keep connection authentication narrow.

Do not place channel-specific authorization decisions in the connection merely because the user is authenticated.

Authentication proves identity; it does not grant subscription access.

Use `rails-security` and `rails-security-engineering` for authentication, session/token, tenant, and trust-boundary analysis.

## Connection lifecycle

A browser tab/device can create its own WebSocket connection.

Model lifecycle explicitly:

```text
connect
-> authenticate
-> establish connection
-> subscribe channels
-> receive broadcasts
-> disconnect
-> reconnect
-> resubscribe
```

Assume connections disappear without an orderly application-level shutdown because of browser lifecycle, mobile/network transitions, proxies, deploys, worker restarts, or provider failure.

Do not treat an in-memory connection registry as durable state.

If presence is required, define lease/expiry semantics rather than assuming `connected` means "user is online."

## Channel boundary

A channel is the logical unit of realtime authorization and message handling.

A channel should define:

- what resource/topic the subscription represents;
- which caller may subscribe;
- which parameters are accepted;
- which stream(s) are opened;
- what client actions are allowed;
- what messages are sent;
- what happens on unsubscribe/disconnect;
- whether the subscription is tenant-scoped.

Keep channel methods small and explicit.

Do not put arbitrary domain workflows inside channel callbacks. Reuse application/domain services for state changes.

Treat client-submitted channel parameters as untrusted.

## Subscription authorization

Every subscription must be authorized against the domain resource it represents.

Typical flow:

```text
authenticate connection
-> normalize subscription parameters
-> resolve tenant/resource
-> authorize caller against resource
-> subscribe only to the authorized stream
```

Never authorize a subscription because:

- the caller is authenticated;
- the resource ID exists;
- the client knows a stream name;
- the client supplied a signed-looking identifier without verifying ownership;
- another controller already performed authorization.

For multi-tenant systems, ensure tenant ownership is part of the server-side lookup/authorization path.

Never construct a broad stream such as `"tenant_notifications"` for private data unless all authorized subscribers are intentionally allowed to receive the entire tenant stream.

## Channel parameters

Treat `params` as untrusted input.

Define:

- accepted keys;
- types;
- normalization;
- resource lookup;
- authorization;
- invalid-parameter behavior.

Prefer stable identifiers over free-form stream names.

Reject unknown or unsafe parameters rather than silently widening the subscription.

Do not embed arbitrary client strings directly into stream names without a bounded naming contract.

## Stream naming

Stream names are part of the authorization contract.

Prefer repository/framework primitives such as:

- `stream_for resource`;
- `broadcast_to resource, payload`;
- stable names derived from canonical resource identity.

When explicit strings are required, define a namespace and identity format.

For tenant/private streams include every identity boundary needed to prevent collisions.

Avoid raw user input in broadcast names.

Never let a client select a broadcast namespace that it could not otherwise authorize.

Use `patterns/rails/action-cable-stream-contract.md`.

## Broadcast contract

Broadcast payloads are wire contracts even when they remain inside one Rails application.

Define:

- event/message type;
- schema/version;
- resource identity;
- payload fields;
- nullability/omission;
- client handling expectations;
- authorization assumptions;
- compatibility behavior during rolling deploy.

Prefer small purpose-built payloads over serializing entire Active Record objects.

Do not broadcast sensitive model attributes merely because they are convenient to serialize.

Do not depend on a database query occurring in the client callback to reconstruct authorization-sensitive state.

When payloads are persisted/replayed elsewhere, compose with `rails-event-driven-messaging` and `rails-distributed-systems`.

## Realtime is not durable delivery

Action Cable broadcastings are time-dependent online delivery.

A disconnected client does not receive a broadcast emitted while it was offline.

Therefore distinguish:

```text
realtime notification
vs
durable business message
```

Use Action Cable for freshness/interaction where missed messages can be reconstructed or safely ignored.

Use Active Job or durable messaging/event infrastructure when delivery itself is business-critical.

Do not use Action Cable as a durable queue.

Do not build durable workflow semantics by assuming Action Cable broadcast history exists.

A robust UI often combines:

```text
initial authoritative HTTP fetch
+
Action Cable live updates
+
reconciliation/refetch after reconnect
```

This pattern makes reconnect gaps explicit.

## Client reconnect and resubscribe

Assume reconnects and duplicate subscription attempts.

The client may reconnect after:

- network failure;
- browser sleep/wake;
- mobile handoff;
- deploy/restart;
- proxy timeout;
- server failure.

Design subscriptions to be safely re-established.

On reconnect, determine whether the client must:

- refetch current state;
- re-subscribe;
- request a snapshot;
- reconcile missed state changes.

Do not claim a single broadcast after reconnect repairs all missed state.

Do not assume a single broadcast after reconnect repairs all missed state.

Where a monotonic version/sequence is available, use it to detect stale client state and trigger reconciliation.

## Client actions

If the channel accepts incoming actions from the client, treat them like an API boundary.

For each action verify:

- authentication;
- authorization;
- parameter validation;
- resource ownership;
- idempotency where duplicate action delivery is possible;
- rate limits/abuse controls;
- domain operation outcome;
- broadcast behavior after successful state change.

Do not trust a client callback that claims an action succeeded.

Do not mutate Active Record directly from channel code when an existing domain service owns the transition.

## Broadcasting after state changes

Broadcast from the authoritative domain/application boundary.

When a message represents committed database state, ensure the broadcast is coordinated with transaction semantics.

Inspect:

- transaction boundary;
- after-commit behavior;
- queued broadcast behavior;
- old/new process compatibility;
- failure between database commit and broadcast;
- reconciliation behavior.

A broadcast should not announce state that later rolled back.

When durable correctness is required, use an outbox/event boundary rather than treating an in-memory broadcast call as atomic with the database transaction.

Compose with `rails-distributed-systems` and `rails-event-driven-messaging`.

## Broadcast fan-out

A broadcast may reach many active subscribers.

Evaluate:

- subscriber count;
- payload size;
- serialization cost;
- frequency;
- per-user versus per-tenant fan-out;
- hot channels;
- Redis/pub/sub bandwidth;
- application server CPU;
- client rendering cost.

Do not broadcast a full object graph to every subscriber.

Prefer coarse-grained state-change messages when clients can refetch authoritative data.

For high-fanout updates, consider:

- per-resource streams;
- per-user streams;
- batched updates;
- client-side coalescing;
- lower update frequency;
- snapshot plus delta model.

## Backpressure and overload

Action Cable does not remove downstream capacity limits.

Review:

- connections per process;
- subscriptions per connection;
- messages per second;
- bytes per second;
- Redis/pub/sub throughput;
- serialization CPU;
- memory per connection;
- browser/client rendering;
- network egress.

Bound high-frequency producers.

Do not add unbounded broadcast loops or per-record broadcast callbacks without measuring fan-out.

A system can fail even when HTTP latency remains healthy because persistent WebSocket connections consume memory and pub/sub bandwidth.

Coordinate with `rails-production-runtime`, `rails-performance`, `ruby-performance`, `ruby-concurrency`, and `rails-reliability-engineering`.

## Realtime capacity model

At minimum estimate:

```text
active_connections
x average subscriptions
x messages/subscription/second
x average payload bytes
```

Also account for:

- connection memory;
- channel object/state;
- Redis/pubsub buffers;
- serializer CPU;
- TLS/network overhead;
- burst rates;
- reconnect storms.

Do not use HTTP request concurrency as a substitute for WebSocket capacity planning.

## Redis and adapter topology

Inspect the subscription adapter and Redis deployment.

Define:

- namespace/key strategy;
- environment isolation;
- connection limits;
- timeout behavior;
- retry policy;
- failure mode;
- memory/eviction policy;
- high-availability topology;
- observability.

Do not share production and non-production pub/sub namespaces.

Do not treat Redis pub/sub as a durable message store.

For critical state, keep authoritative data in the database/event system rather than Redis broadcast history.

## Failure behavior

Define what happens when realtime infrastructure fails.

Possible strategies:

- continue authoritative HTTP/API operation and degrade live updates;
- queue or persist a notification for later retrieval;
- require client reconnect/refetch;
- disable a non-critical realtime feature;
- fail the user action when realtime acknowledgement is part of the business contract.

The correct fallback depends on business semantics.

Do not make a core database transaction fail solely because an optional realtime broadcast is unavailable unless the contract explicitly requires atomic realtime acknowledgement.

Do not silently claim realtime delivery succeeded because the broadcast call returned without raising.

## Security and privacy

WebSockets are long-lived authorization contexts.

Review:

- authentication lifetime;
- session/token revocation;
- allowed origins;
- cookie use;
- CSRF/authentication semantics for client actions;
- channel authorization;
- tenant isolation;
- stream naming;
- payload sensitivity;
- connection identifiers;
- logs/telemetry.

Allowed origin configuration is part of the WebSocket trust boundary.

Never put private resource data into a broadly shared broadcast.

Never log access tokens, cookies, authorization headers, or full sensitive payloads.

Use `rails-security` and `rails-security-engineering` for threat modeling and abuse-case analysis.

## Operational lifecycle

Deployments and restarts interrupt connections.

Define:

- drain/reconnect behavior;
- client retry/backoff;
- stale connection cleanup;
- readiness versus ability to accept new WebSockets;
- graceful shutdown;
- Redis connection cleanup;
- monitoring during deploys.

Avoid synchronized client reconnect storms after a fleet restart.

Use jittered client reconnect/backoff where the client supports configurable policy.

Coordinate deployment lifecycle with `rails-production-runtime`, `rails-release-engineering`, and `rails-incident-engineering`.

## Observability

Monitor lifecycle and throughput, not only exceptions.

Useful bounded signals:

- active connection count;
- subscription count;
- connection attempts/rejections;
- subscribe/unsubscribe counts;
- disconnect reason class;
- broadcast count;
- broadcast latency;
- payload byte buckets;
- failed broadcasts;
- Redis/pubsub errors;
- reconnect rate;
- per-channel hotness;
- consumer processing/failure where observable.

Avoid raw user IDs or stream names as unbounded metric labels.

Correlate channel actions and broadcasts with request/job/business-event IDs where safe.

Use `rails-observability` for telemetry design.

## Testing

Test at the smallest realtime boundary:

- connection authentication accepts authorized callers;
- unauthenticated connections are rejected;
- channel subscription authorization is correct;
- cross-tenant subscriptions are rejected;
- stream names are deterministic and isolated;
- broadcasts reach the intended channel;
- unauthorized channels receive nothing;
- client actions validate parameters/authorization;
- broadcast payload schema is stable;
- reconnect/resubscribe triggers reconciliation where required;
- channel unsubscribe cleans up correctly;
- provider/adapter failure degrades according to contract.

Use Action Cable test helpers where available and deterministic local adapters.

Do not make ordinary tests depend on a live Redis cluster.

For frontend consumer behavior, use focused client tests rather than testing browser rendering through every server-side channel test.

## Reference example

A channel that authorizes the subscription before streaming, and pairs an implicit resource stream with an explicit lifecycle stream.

```ruby
class RoomChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find_by(id: params[:room_id])
    return reject unless room && current_user.member_of?(room)

    stream_for room                      # broadcast_to(room, ...) reaches these subscribers
    stream_from "room:#{room.id}:system" # explicit stream for join/leave lifecycle events
  end

  def unsubscribed
    StopPresenceTrackingJob.perform_later(current_user.id, params[:room_id])
  end
end

# Server-side broadcast after a state change (never trust the client to echo state):
# RoomBroadcastJob.perform_later(room)  ->  RoomChannel.broadcast_to(room, payload)
```

## Agent review checklist

- [ ] runtime/Action Cable version resolved
- [ ] connection authentication identified
- [ ] channel authorization identified
- [ ] tenant/resource ownership verified
- [ ] channel parameters validated
- [ ] stream names bounded and isolated
- [ ] broadcast payload contract explicit
- [ ] realtime versus durable semantics explicit
- [ ] reconnect/resubscribe behavior defined
- [ ] state reconciliation defined
- [ ] transaction/broadcast ordering reviewed
- [ ] client actions treated as API boundaries
- [ ] fan-out and payload size measured
- [ ] WebSocket capacity estimated
- [ ] Redis/adapter topology reviewed
- [ ] failure/degradation semantics explicit
- [ ] allowed origins/security reviewed
- [ ] deploy/restart lifecycle reviewed
- [ ] lifecycle/broadcast telemetry bounded
- [ ] deterministic tests cover auth, isolation, subscription, and broadcast behavior

## Anti-patterns / failure modes

- authentication without channel authorization;
- client-selected arbitrary stream names;
- blob/resource IDs treated as authorization;
- broadcasting private data to broad tenant/global streams;
- using Action Cable as a durable queue;
- assuming disconnected clients receive missed broadcasts;
- broadcasting entire Active Record objects;
- domain writes embedded directly in channel callbacks;
- broadcast before committed state;
- unbounded per-record broadcast callbacks;
- ignoring Redis/pub/sub capacity;
- testing against live Redis in every CI run;
- synchronized reconnect storms after deployment;
- logging secrets or sensitive payloads;
- using raw user IDs or stream names as unbounded telemetry labels;
- making optional realtime delivery a hidden database transaction dependency.

## Verification

For a realtime feature:

```text
connection auth
-> channel authorization
-> stream contract
-> broadcast contract
-> state/reconciliation semantics
-> focused Action Cable tests
-> capacity model
-> security checks
-> deploy/reconnect verification
-> regression suite
```

For production incidents verify whether failure occurred at:

```text
client
-> WebSocket connection
-> authentication
-> subscription
-> pub/sub adapter
-> broadcast producer
-> serialization
-> client consumer
```

Never claim realtime delivery, fan-out capacity, or reconnect safety without runtime evidence.

## Rails 8 current framework considerations

- Solid Cable provides a database-backed pub/sub option for Action Cable. Treat its retention, polling/pub/sub capacity, failure behavior, and deployment topology as runtime concerns.
- Preserve the same authorization, stream identity, reconciliation, and overload protections regardless of whether Redis or Solid Cable is the transport.

## Source foundation

Primary Rails guidance:

- https://guides.rubyonrails.org/action_cable_overview.html
- https://api.rubyonrails.org/classes/ActionCable.html
- https://api.rubyonrails.org/classes/ActionCable/Channel/Base.html

Composed repository skills:

- `skills/rails-security/SKILL.md`
- `skills/rails-security-engineering/SKILL.md`
- `skills/rails-active-job/SKILL.md`
- `skills/rails-event-driven-messaging/SKILL.md`
- `skills/rails-distributed-systems/SKILL.md`
- `skills/rails-reliability-engineering/SKILL.md`
- `skills/rails-performance/SKILL.md`
- `skills/ruby-performance/SKILL.md`
- `skills/ruby-concurrency/SKILL.md`
- `skills/rails-production-runtime/SKILL.md`
- `skills/rails-release-engineering/SKILL.md`
- `skills/rails-observability/SKILL.md`
- `skills/rails-test-engineering/SKILL.md`
- `skills/rails-test-engineering/SKILL.md`

## Rails Action Cable changes

For Action Cable/realtime changes:
- inspect ApplicationCable::Connection, channel hierarchy, subscription parameters, stream naming, broadcast producers, client reconnect behavior, adapter/Redis configuration, process topology, capacity, and tests before implementation;
- keep WebSocket connection authentication separate from per-channel/resource authorization;
- treat all channel parameters and client actions as untrusted API input;
- authorize subscriptions through the owning resource/tenant and never treat a blob/resource ID or stream name as authorization;
- use bounded deterministic stream names and prefer framework resource primitives such as stream_for/broadcast_to when appropriate;
- treat broadcast payloads as versioned wire contracts and avoid serializing entire Active Record objects or sensitive fields;
- do not use Action Cable as durable messaging; define reconnect/refetch reconciliation when missed broadcasts matter;
- coordinate broadcasts with committed state and use outbox/durable event infrastructure when delivery correctness requires it;
- size WebSocket connections, subscriptions, message rate, payload bytes, Redis/pubsub, memory, CPU, and reconnect bursts separately from HTTP capacity;
- define degraded behavior when Redis/Action Cable is unavailable rather than making optional realtime delivery an accidental transaction dependency;
- review allowed origins, credential/session lifetime, tenant isolation, secrets, and sensitive payloads;
- avoid synchronized reconnect storms during deploys and test connection/channel/broadcast behavior with deterministic local adapters;
- never claim realtime delivery or capacity without runtime evidence.
