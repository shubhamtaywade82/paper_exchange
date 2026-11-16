---
name: rails-active-job
description: Use when creating, changing, reviewing, debugging, testing, or operating Rails Active Job and queue-backed background processing.
---

# Rails Active Job

## Purpose

Treat a background job as a distributed execution contract, not merely a method moved off the request thread.

A job has at least these boundaries:

```text
enqueue -> serialize -> persist -> schedule -> claim -> execute
       -> retry/discard/fail -> observe -> recover/replay
```

The current Rails guide documents Active Job as the common interface for background jobs and Solid Queue as the default backend in Rails 8+. Solid Queue provides delayed jobs, concurrency controls, priorities, recurring tasks, and database-backed execution. 

## Activate when

- creating or changing `ApplicationJob` or Active Job classes
- moving synchronous work to the background
- changing queues, priorities, scheduling, or bulk enqueue behavior
- designing retries, backoff, discard rules, or failure reporting
- changing job arguments or serialization
- changing enqueue behavior inside database transactions
- adding idempotency/deduplication
- adding concurrency limits
- using or reviewing Rails 8.1 Active Job Continuations (`ActiveJob::Continuable`)
- configuring Solid Queue workers/processes/dispatchers/schedulers
- adding recurring jobs
- changing job shutdown/recovery semantics
- testing asynchronous workflows
- debugging stuck, duplicated, lost, retried, or unexpectedly discarded jobs
- changing job observability or operational recovery

## Repository inspection

Inspect:

1. Ruby/Rails version and Active Job API available in that version
2. queue adapter and adapter-specific gem/version
3. `ApplicationJob` and inherited job bases
4. job classes and queue naming
5. job tests and test helpers
6. database transaction boundaries around `perform_later`
7. retry/discard/error-reporting configuration
8. worker/queue configuration
9. concurrency settings and downstream capacity
10. recurring-task configuration
11. deployment/restart/shutdown behavior
12. serialization/custom serializers/GlobalID usage
13. idempotency or uniqueness mechanisms
14. monitoring, structured logs, metrics, and failed-job tooling
15. existing job conventions before introducing new abstractions

## Job boundary

A useful job should make explicit:

```text
input contract
queue
priority
execution side effects
retry policy
discard policy
idempotency requirement
concurrency boundary
transaction boundary
observability
failure/recovery semantics
```

Do not hide business behavior in a giant `perform` method merely because it runs asynchronously. Keep domain/application behavior in the repository's appropriate service/domain layer and make the job a durable execution boundary.

## Arguments and serialization

Prefer small, stable arguments.

Use identifiers or supported serializable values when possible:

```ruby
ProcessInvoiceJob.perform_later(invoice.id)
```

Active Job supports common primitive/container types and Active Record objects through GlobalID. Passing a live record means deserialization can fail later if the record no longer exists. 

Do not pass:

- database connections
- request objects
- controllers
- open file handles
- transient service instances
- arbitrary complex runtime state
- secrets that should not be persisted in the queue payload

When passing an Active Record object is appropriate, understand that it is serialized by GlobalID and is looked up again when the job runs.

For custom types, inspect serializer support rather than inventing ad-hoc Marshal/JSON behavior.

## Idempotency

Assume a job can run more than once.

Make side effects safe against duplicate execution where retry/redelivery can repeat them.

Common techniques:

- database unique constraints
- idempotency keys
- state transitions guarded by predicates
- upserts
- compare-and-set updates
- external API idempotency keys
- durable execution records

Do not use an in-memory mutex as an idempotency mechanism across processes or hosts.

A job that sends an email, charges a payment, publishes an event, or calls an external API must explicitly answer:

```text
"What happens if perform runs twice?"
```

## Transactions and enqueue timing

Do not assume:

```text
record.save!
Job.perform_later(record.id)
```

is equivalent to "the job can safely run after the record is committed."

When enqueueing occurs inside a transaction, inspect the queue adapter and the repository's transaction semantics.

Rails supports `enqueue_after_transaction_commit` and documents it as a way to defer enqueueing until a surrounding transaction commits. It can be configured per job or on a common job base. 

Use this only when its semantics match the application's contract. Do not silently couple application correctness to a queue database sharing the application database.

A robust design should state whether the job requires:

- committed database state
- same-transaction durability
- independent queue storage
- eventual consistency

## Retry policy

Use `retry_on` for transient failures where re-execution can reasonably succeed.

Specify:

- exception class
- attempts
- delay/backoff
- queue/priority changes when justified
- jitter where supported
- terminal behavior after retries
- error reporting

Rails' current API documents `retry_on` with configurable wait, attempts, queue, priority, jitter, reporting, and a terminal block. 

Example:

```ruby
class SyncCustomerJob < ApplicationJob
  retry_on ExternalServiceTimeout,
    wait: :polynomially_longer,
    attempts: 5,
    report: true

  def perform(customer_id)
    # ...
  end
end
```

Do not retry deterministic bugs, malformed input, authorization failures, or permanent domain-invalid states.

## Discard policy

Use `discard_on` when the work is no longer meaningful and retrying cannot make it valid.

Typical examples include deserialization of an object that has been deliberately removed, or a domain condition where the work is permanently obsolete.

Rails documents `discard_on` separately from `retry_on`; it performs no retry attempts for matching exceptions. 

Do not use discard as a substitute for fixing an unknown production failure.

Report discarded failures when operational visibility matters.

## Retry storm prevention

A retry is a capacity decision.

Before adding retries, determine:

```text
failure frequency
x
retry attempts
x
backoff duration
x
job concurrency
=
additional system load
```

Protect dependencies from amplification.

Use backoff/jitter and appropriate concurrency/queue isolation rather than immediate repeated retries.

## Concurrency controls

Concurrency has two distinct meanings:

1. worker capacity: how many jobs a worker can execute
2. business/resource concurrency: how many jobs for the same key may overlap

Solid Queue provides `limits_concurrency` for the second category. The current documentation supports a key, limit, duration, optional group, and conflict behavior.

Example:

```ruby
class RebuildAccountJob < ApplicationJob
  limits_concurrency(
    to: 1,
    key: ->(account_id) { account_id },
    duration: 5.minutes
  )
end
```

Use a concurrency control when overlap itself violates a contract.

Do not use a concurrency limit as a generic replacement for worker sizing. For high-throughput throttling, queue-level worker capacity can be simpler and cheaper.

Always analyze:

- database connection pool
- external API limits
- lock contention
- CPU/memory
- downstream queue capacity
- number of worker processes
- thread count per process

## Queues and priorities

Queues are capacity/isolation boundaries, not merely labels.

Use separate queues when workloads have materially different:

- latency requirements
- resource usage
- failure characteristics
- external rate limits
- operational ownership

Avoid creating a unique queue for every job without operational justification.

Remember that queue order and numeric priority are backend-dependent. With Solid Queue, queue order has precedence across queues and priority applies within a queue. 

## Scheduling and recurring tasks

Scheduled jobs and recurring tasks are different concepts:

```text
scheduled job
→ one future execution

recurring task
→ recurring enqueue schedule
```

Use the backend's durable scheduler/configuration rather than application boot code that manually creates timers.

For recurring jobs, define:

- schedule
- timezone expectations
- idempotency
- overlap policy
- failure/retry semantics
- deployment behavior
- disable/maintenance behavior

Solid Queue uses `config/recurring.yml` for recurring tasks and a scheduler process.

## Bulk enqueue

For large batches, consider `ActiveJob.perform_all_later` instead of issuing individual enqueue calls when the backend supports the desired behavior.

Bulk enqueue reduces queue-store round trips. However, backend-specific constraints can change the trade-off. Solid Queue documents that concurrency-controlled jobs need individual enqueue handling to enforce concurrency limits, reducing the benefit of bulk enqueue in that case.

Do not bulk enqueue millions of jobs without analyzing queue storage, database write pressure, payload size, and worker capacity.

## Callbacks

Active Job provides enqueue and perform lifecycle callbacks.

Use callbacks for narrow cross-cutting concerns such as instrumentation.

Avoid putting business workflows inside `before_enqueue`, `after_enqueue`, `before_perform`, or `after_perform` merely because the hook is available.

Keep callback behavior:

- small
- observable
- deterministic
- safe under retries

Remember that bulk enqueue has different callback behavior from individual enqueue.

## Error reporting

Job failures need operational visibility.

Prefer the repository's existing error reporter/logging infrastructure.

A common pattern is reporting exceptions through `Rails.error` and then re-raising so the queue backend retains failure semantics.

Do not rescue `StandardError` and silently return success.

## Shutdown and graceful termination

Job execution is interruptible.

For long-running jobs:

- make work restartable
- persist progress when useful
- use checkpoints/cursors for large datasets
- keep side effects idempotent
- understand worker TERM/QUIT semantics
- avoid assuming the process will always reach the end of `perform`

Current Active Job supports continuations for resumable multi-step jobs in Rails versions that expose `ActiveJob::Continuable`. Use version-aware guidance before activating this API.

## Observability

At minimum, be able to answer:

- what job ran?
- which arguments/identifier?
- when was it enqueued?
- when did execution begin/end?
- which queue?
- attempt count?
- duration?
- failure exception?
- retry/discard outcome?
- correlation/request ID?
- what downstream dependency was involved?

Never log secrets or sensitive payloads merely for debugging.

Prefer structured events/metrics over parsing free-form log strings.

## Security

Queue payloads are durable data.

Treat arguments as sensitive persistence where applicable.

Do not enqueue:

- passwords
- access tokens
- private credentials
- unnecessary personal data
- entire request/session objects

Authorize again at execution time when permissions may have changed since enqueue.

Do not assume authorization at enqueue time remains valid later.

## Testing

Test jobs at the behavior boundary.

At minimum cover the applicable dimensions:

- enqueued job class and arguments
- queue selection
- scheduling
- perform behavior
- retry/discard semantics
- idempotency
- transaction/enqueue boundary
- concurrency key/limit
- failure reporting
- deserialization behavior
- bulk enqueue behavior when used

Rails provides dedicated job testing support and separate guidance for isolated/contextual job tests.

Prefer deterministic fake/adaptor behavior over sleeping in tests.

## Debugging procedure

For a failing or duplicated job:

```text
1. capture job class, job_id, queue, arguments, attempt
2. identify adapter and version
3. determine whether enqueue succeeded
4. inspect serialized arguments/deserialization
5. inspect worker/queue selection
6. inspect transaction boundary
7. inspect retry/discard handlers
8. inspect idempotency guarantees
9. inspect concurrency controls
10. inspect downstream failure/rate limiting
11. inspect worker shutdown/restarts
12. replay safely when possible
```

Never diagnose a duplicate side effect as "Rails ran it twice" without tracing enqueue, claim, retry, and application-level idempotency.

## Agent review checklist

- [ ] Rails/Ruby/Active Job/adapter versions resolved
- [ ] arguments are stable and serializable
- [ ] idempotency behavior is explicit
- [ ] transaction/enqueue semantics are understood
- [ ] retry exceptions are genuinely transient
- [ ] retry count/backoff are justified
- [ ] discard behavior is intentional
- [ ] concurrency boundary is explicit
- [ ] queue/priority choice is justified
- [ ] downstream capacity is respected
- [ ] recurring/scheduled behavior is durable
- [ ] shutdown/restart behavior is safe
- [ ] payloads do not leak secrets
- [ ] tests cover failure and retry paths
- [ ] observability supports diagnosis/recovery
- [ ] final diff is narrow

## Anti-patterns

- using `rescue StandardError; nil; end` in `perform`
- infinite immediate retries
- retries for permanent validation/authentication failures
- using sleep loops inside jobs as a scheduler
- relying on process-local state for distributed idempotency
- assuming enqueue inside a transaction always waits for commit
- passing huge Active Record objects or entire request state as arguments
- putting core business logic into job callbacks
- creating a queue per job without operational reasoning
- using concurrency controls when simple worker capacity is the real requirement
- bulk enqueuing without measuring queue-store pressure
- logging credentials or full sensitive payloads
- treating successful enqueue as successful execution

## Verification

Never claim a job is reliable from a unit test that only exercises `perform`.

Verify the enqueue contract, execution behavior, failure policy, and relevant adapter/worker configuration.

For Rails/Solid Queue changes, inspect actual queue configuration and use version-supported commands/tests.


## Rails 8.1 current framework considerations

- Rails 8.1 exposes `ActiveJob::Continuable` for resumable multi-step jobs. Inspect the repository's supported Rails version and job adapter before using continuations.
- Design each continuation step around durable progress and restart semantics; a step boundary is not a substitute for idempotency or explicit retry behavior.

## Source foundation

Primary Rails guidance:
- Active Job Basics: https://guides.rubyonrails.org/active_job_basics.html
- Rails Testing: https://guides.rubyonrails.org/testing.html
- Solid Queue: https://github.com/rails/solid_queue

Use the target Rails/Active Job/adapter version as the compatibility authority when APIs or semantics differ.

## Active Job/background-job changes

For background-job changes:
- resolve the Rails/Active Job/queue-adapter versions first;
- inspect ApplicationJob and existing job conventions;
- make serialization and idempotency explicit;
- classify retryable versus permanent failures;
- inspect transaction/commit semantics when enqueueing from database transactions;
- analyze concurrency and downstream capacity;
- verify queue/worker configuration and shutdown behavior when operational behavior changes;
- test enqueue, perform, failure, retry/discard, and duplicate-execution behavior as applicable.
