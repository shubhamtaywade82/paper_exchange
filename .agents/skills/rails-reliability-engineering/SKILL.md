---
name: rails-reliability-engineering
description: Use when Rails/Ruby systems need explicit reliability objectives, failure containment, graceful degradation, dependency isolation, load shedding, recovery planning, or resilience testing.
---

# Reliability Engineering & Resilience

## Purpose

Treat reliability as an engineered system property with explicit objectives, failure budgets, containment boundaries, recovery procedures, and evidence.

A reliable system does not merely retry failures. It limits blast radius, preserves critical behavior under dependency failure, sheds unsafe load, recovers predictably, and exposes whether reliability objectives are being met.

Core flow:

define critical user journeys
-> define SLIs
-> set SLOs and error budgets
-> map dependencies/failure modes
-> choose containment/degradation
-> bound retries/concurrency
-> define recovery objectives
-> observe budget/saturation/failure
-> test failure and recovery
-> review operational evidence
-> evolve the design

Compose this skill with:

- rails-observability for telemetry, health, correlation, and error reporting;
- rails-performance for workload/capacity evidence;
- rails-api-integration for dependency timeout/retry/compatibility;
- rails-distributed-systems for cross-service failure and consistency;
- rails-event-driven-messaging for broker/consumer failure and lag;
- rails-production-runtime for process lifecycle, restart, and deployment;
- rails-active-job for retry/queue semantics;
- ruby-concurrency for bounded workers and isolation;
- rails-database-engineering for transaction, lock, replica, and backup/recovery concerns;
- rails-security for failure-mode abuse and trust boundaries.

## Activate when

- defining or reviewing SLI/SLO/error-budget contracts;
- diagnosing recurring availability/latency/reliability failures;
- adding circuit breakers or dependency failure isolation;
- designing graceful degradation or stale/fallback behavior;
- introducing bulkheads or isolated worker/resource pools;
- adding load shedding/admission control;
- planning retries across multiple layers;
- reviewing cascading failure or retry storms;
- defining RTO/RPO and recovery procedures;
- reviewing backups, restore, failover, or reconciliation;
- introducing resilience tests, fault injection, or game days;
- reviewing dependency criticality or blast radius;
- operating systems where overload is as dangerous as component failure.

Do not activate merely because a system has a production bug. Use the narrowest reliability capability justified by the failure mode.

## Repository inspection

Inspect:

1. critical user journeys and business priority;
2. existing SLIs, SLOs, dashboards, alerts, and incident history;
3. request/job/message latency and saturation metrics;
4. dependency inventory and failure behavior;
5. HTTP timeout/retry/circuit conventions;
6. queue/broker retry, dead-letter, and lag behavior;
7. database pool, replica, lock, transaction, and failover behavior;
8. Puma/worker/process topology and resource limits;
9. cache/fallback/stale-data behavior;
10. feature flags and kill-switch conventions;
11. backup/restore/failover/reconciliation procedures;
12. deployment and rollback mechanics;
13. existing resilience/fault-injection tests;
14. operational runbooks and ownership.

Do not invent an SLO, breaker threshold, timeout, or recovery target without workload/business evidence or an explicit contract.

## Reliability objectives

Reliability is a property of a user-visible contract.

Define the critical journey first:

`request -> application work -> dependencies -> durable state -> response`

Possible SLIs:

- availability/success rate;
- latency percentile;
- freshness/staleness;
- queue age/processing delay;
- correctness/failed business operations;
- durability/recovery success;
- dependency success where it affects the user journey.

An SLO states the target over a defined window.

An error budget is the allowed failure implied by that target.

Do not treat every technical metric as an SLO. A metric becomes an SLI when it measures an aspect of the service contract.

Avoid arbitrary ultra-high targets. The target must reflect user impact, business criticality, architecture, and operating cost.

Use `patterns/rails/slo-error-budget.md`.

## Error budgets and operational decisions

Use the error budget to change engineering behavior.

When budget consumption is high:

- reduce risky releases;
- prioritize reliability work;
- investigate dominant failure modes;
- avoid hiding failures by widening timeouts/retries;
- confirm whether the SLO or SLI is measuring the right user impact.

Do not turn the error budget into a punitive score. It is a decision mechanism for balancing feature velocity and reliability.

Use burn-rate evidence when alerting on rapid SLO consumption. Avoid alerts on every single error.

## Dependency criticality

Classify dependencies:

- critical: user journey cannot complete correctly without it;
- degradable: reduced functionality is acceptable;
- optional: feature can be omitted;
- asynchronous: failure can be absorbed temporarily.

For each dependency define:

- timeout;
- retryability;
- concurrency limit;
- fallback/degradation;
- circuit behavior;
- observability;
- operator ownership.

Do not classify a dependency as optional merely because the API call is technically not required.

Use `patterns/rails/dependency-failure-boundary.md`.

## Circuit breakers

A circuit breaker controls repeated calls to an unhealthy dependency.

Typical states:

`closed -> open -> half-open -> closed/open`

Define:

- failure classification;
- rolling observation window;
- threshold or failure ratio;
- open duration;
- half-open probe policy;
- excluded failures;
- fallback behavior;
- metrics.

Do not count validation/authorization failures as dependency health failures unless they represent actual downstream unavailability.

A circuit breaker is not a timeout, retry policy, cache, or load balancer.

Do not put one global breaker around unrelated dependencies or tenants unless they truly share a failure domain.

Use `patterns/rails/circuit-breaker.md`.

## Bulkheads

A bulkhead isolates resources so one failing workload cannot exhaust shared capacity.

Possible boundaries:

- thread/executor pool;
- job queue;
- database connection pool;
- external client connection pool;
- per-tenant/per-provider concurrency;
- memory/work queue.

Define:

- isolated capacity;
- queue/rejection behavior;
- ownership;
- saturation metrics;
- recovery.

Do not create many tiny pools without evidence; fragmentation can reduce useful capacity.

Use `patterns/rails/bulkhead-isolation.md`.

## Load shedding and admission control

When demand exceeds safe capacity, controlled rejection can preserve critical work.

Prefer:

- explicit rate limits;
- bounded queues;
- concurrency caps;
- priority queues;
- early rejection;
- per-tenant quotas;
- degraded responses.

Define which work is protected and which may be dropped.

A system that accepts unlimited work and fails later is not necessarily more reliable.

Never silently drop durable business operations without a recovery/audit contract.

Use `patterns/rails/load-shedding.md`.

## Graceful degradation

Design a lower-cost behavior before failure occurs.

Examples:

- stale-but-valid cache;
- omit optional enrichment;
- read-only mode;
- reduced result set;
- asynchronous completion;
- fallback provider;
- feature flag disablement.

For every fallback define:

- freshness;
- correctness boundary;
- user-visible semantics;
- security/authorization implications;
- observability;
- exit/recovery condition.

Never return stale or fallback data where the contract requires authoritative current state.

Use `patterns/rails/graceful-degradation.md`.

## Retry and timeout coordination

Retries can amplify an incident.

Model the whole chain:

`caller timeout x attempts x concurrency x downstream fan-out`

Define one coherent retry budget across:

- HTTP client;
- Active Job;
- broker redelivery;
- saga step;
- operator replay.

Use exponential backoff/jitter where appropriate.

Avoid stacking independent retries that turn one dependency failure into a traffic storm.

Coordinate with `rails-api-integration`, `rails-active-job`, and `rails-event-driven-messaging`.

## Cascading failure analysis

For an incident, trace:

`resource saturation -> queueing -> timeout -> retry -> more load -> further saturation`

Look for:

- shared thread pools;
- shared database pools;
- retry synchronization;
- long timeouts;
- unbounded queues;
- dependency fan-out;
- cache stampedes;
- circuit breakers that fail too late;
- load shedding that protects low-priority traffic instead of critical work.

Fix the positive feedback loop, not only the first symptom.

## Recovery objectives

Define:

- RTO: maximum acceptable recovery time;
- RPO: maximum acceptable data-loss window;
- recovery owner;
- recovery source of truth;
- dependencies required for restore;
- failover procedure;
- reconciliation procedure;
- validation after recovery.

Recovery is not complete when the process starts. It is complete when the critical invariant and user journey are restored and verified.

Use `patterns/rails/recovery-objectives.md`.

## Disaster recovery and reconciliation

Backups are only useful when restore is tested.

Verify:

- backup coverage;
- retention;
- encryption/access;
- restore procedure;
- restore time;
- data validation;
- application compatibility;
- downstream reconciliation;
- idempotent reprocessing.

For eventually consistent systems, define how missing/out-of-sync state is detected and repaired.

Do not claim disaster recovery readiness from backup existence alone.

## Resilience testing

Test realistic failures at the boundary that owns the failure mode.

Examples:

- dependency timeout/outage;
- broker lag;
- database saturation;
- exhausted worker pool;
- cache unavailable;
- malformed dependency response;
- retry storm;
- stale replica;
- process restart during work;
- failed restore/recovery step.

Prefer deterministic fault injection and bounded scenarios.

A resilience test should specify:

`fault -> expected containment -> expected user behavior -> recovery -> verification`

Do not perform uncontrolled destructive experiments against production without an explicit, authorized experiment contract.

Use `patterns/rails/resilience-testing.md`.

## Observability

Reliability requires four classes of evidence:

1. user-impact SLIs;
2. saturation/capacity;
3. dependency/failure signals;
4. recovery state.

Track safe, low-cardinality dimensions such as operation, dependency, status class, queue, tenant class, and region where applicable.

Propagate correlation across synchronous and asynchronous boundaries.

Do not page on a raw exception count without relating it to user impact or a known operational failure mode.

Compose with `rails-observability`.

## Change and rollout safety

Reliability changes can themselves create incidents.

For breakers, bulkheads, load shedding, and fallbacks verify:

- default behavior;
- activation thresholds;
- failure mode;
- rollback/disable path;
- metric visibility;
- configuration validation.

For rolling deployment, maintain old/new compatibility for queued jobs, messages, APIs, and durable state.

Use feature flags or staged rollout where the repository supports them.

## Reference example

A circuit breaker guarding a flaky dependency: failures trip it, the cooldown half-opens it, one success closes it again.

```ruby
class CircuitBreaker
  class OpenError < StandardError; end

  def initialize(failsafe:, threshold: 2, cooldown: 5, clock: Time)
    @failsafe = failsafe
    @threshold = threshold
    @cooldown = cooldown
    @clock = clock
    @failures = 0
    @opened_at = nil
  end

  def call
    raise OpenError, "circuit open" if open? && !half_open_window?

    begin
      result = @failsafe.call
      @failures = 0
      @opened_at = nil
      result
    rescue StandardError
      @failures += 1
      @opened_at = @clock.now if @failures >= @threshold
      raise
    end
  end

  private

  def open? = !@opened_at.nil?
  def half_open_window? = @clock.now >= @opened_at + @cooldown
end

attempts = 0
breaker = CircuitBreaker.new(
  failsafe: -> { attempts += 1; raise "provider 500" },
  clock: (now = Time.utc(2026, 1, 1); Struct.new(:now).new(now))
)

2.times { begin; breaker.call; rescue StandardError; end }
begin
  breaker.call
  raise "should still be open"
rescue CircuitBreaker::OpenError => e
  puts "tripped after 2 failures: #{e.message}"
end
puts "failures counted: #{attempts} (third call never reached the provider)"
```

## Agent review checklist

- [ ] critical user journey identified
- [ ] SLI measures user-visible impact
- [ ] SLO window/target explicit
- [ ] error budget semantics explicit
- [ ] dependency criticality classified
- [ ] timeout/retry budget coordinated
- [ ] circuit-breaker conditions justified
- [ ] bulkhead boundary tied to a shared resource
- [ ] load-shed policy protects critical work
- [ ] degradation fallback preserves correctness/security
- [ ] RTO/RPO explicit where recovery matters
- [ ] restore/failover/reconciliation tested
- [ ] resilience test has fault, expected containment, recovery, and verification
- [ ] capacity/saturation evidence exists
- [ ] alerts map to actionable user/system impact
- [ ] rollback/disable path exists for resilience controls
- [ ] old/new deployment compatibility considered

## Anti-patterns

- arbitrary 99.99% SLO without user/business evidence;
- treating every metric as an SLI;
- retrying every exception;
- stacking retries independently at every layer;
- circuit breaker on validation failures;
- one global breaker for unrelated failure domains;
- bulkheads that fragment capacity without justification;
- unbounded queues used as a substitute for capacity;
- load shedding without priority semantics;
- silent dropping of durable business work;
- fallback data that violates correctness/security requirements;
- backups without restore tests;
- declaring DR complete because a process boots;
- destructive chaos experiments without a bounded contract;
- alerts that page on noise while missing saturation or user impact.

## Verification

For reliability design verify:

`objective -> failure model -> control -> user behavior -> recovery -> evidence`

For a dependency:

`timeout -> retry -> breaker -> fallback/degradation -> recovery`

For overload:

`arrival -> capacity -> admission -> protected work -> recovery`

For disaster recovery:

`failure -> restore/failover -> reconcile -> validate -> user journey`

Report the reliability objective, failure mode, containment control, degradation semantics, recovery target, test evidence, and remaining assumptions.

## Source foundation

- Rails Error Reporting: https://guides.rubyonrails.org/error_reporting.html
- Rails Active Support Instrumentation: https://guides.rubyonrails.org/active_support_instrumentation.html
- Rails Active Job: https://guides.rubyonrails.org/active_job_basics.html
- Rails Testing: https://guides.rubyonrails.org/testing.html
- Repository skills: rails-observability, rails-performance, rails-api-integration, rails-distributed-systems, rails-event-driven-messaging, rails-production-runtime, rails-active-job, ruby-concurrency

## Reliability engineering changes

For reliability, resilience, overload, or recovery work:
- identify the critical user journey before choosing infrastructure metrics;
- define user-visible SLIs, an evidence-based SLO/window, and the resulting error budget;
- classify dependencies as critical, degradable, optional, or asynchronous;
- bound timeout/retry/concurrency budgets across every layer instead of stacking independent retries;
- use circuit breakers only for justified dependency failure domains and exclude deterministic caller errors from health signals;
- use bulkheads to isolate genuinely shared resources and verify capacity fragmentation does not create a new bottleneck;
- define load-shed priorities and never silently discard durable business work;
- make graceful degradation explicit, including freshness, correctness, authorization, and recovery semantics;
- define RTO/RPO and verify restore, failover, reconciliation, and post-recovery invariants where recovery matters;
- resilience-test failure containment and recovery with deterministic, bounded fault injection;
- make reliability controls observable, reversible, and compatible with rolling deployment;
- report measured evidence and remaining assumptions instead of claiming resilience from structural patterns alone.
