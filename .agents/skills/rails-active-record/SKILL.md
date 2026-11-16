---
name: rails-active-record
description: Use when implementing or reviewing deep Active Record model, relation, query, persistence lifecycle, scope, callback, bulk-write, deletion, or loading behavior. Also covers routine model, migration, query, scope, callback, and transaction changes.
---

# Rails Active Record

## Purpose

Treat Active Record as both an object/persistence protocol and a query-building system whose behavior must remain explicit at the model, relation, and database boundaries.

This skill deepens the foundational rails-active-record skill. It owns Active Record object and Relation semantics; rails-database-engineering owns production database mechanics such as schema migration, indexes, constraints, transaction isolation, locking, connection pools, and query-plan operations. rails-associations and rails-validations remain specialized ownership boundaries.

## Activate when

- changing ActiveRecord::Base or ApplicationRecord model behavior
- adding or changing scopes or Relation composition
- changing query loading, projection, ordering, grouping, joins, or aggregation
- changing persistence lifecycle behavior
- changing save, update, destroy, or delete semantics
- introducing or reviewing Active Record callbacks
- changing bulk update/delete/import behavior
- changing eager loading, strict loading, or N+1 behavior
- reviewing default_scope or unscoped behavior
- changing serialized or typed Active Record attributes
- debugging differences between in-memory model state and persisted database state
- reviewing Active Record code for accidental materialization or hidden queries

For routine model, migration, or query changes, `rails-active-record` is the lighter entry point; activate this skill only when the deep boundaries above are actually in play.

## Boundary ownership

| Concern | Primary skill |
|---|---|
| Active Record model and Relation semantics | rails-active-record |
| Associations/cardinality/dependent relationships | rails-associations |
| Model validation/error semantics | rails-validations |
| Non-persisted Rails model protocol | rails-active-model |
| Schema/migration/index/constraint engineering | rails-database-engineering |
| Query performance measurement/N+1 investigation | rails-performance |
| Request input/output boundary | rails-action-controller |
| Domain workflow extraction | ruby-domain-modeling / ruby-service-objects |
| Async lifecycle/retries | rails-active-job |

Do not collapse these skills into one model abstraction merely because they all touch Active Record.

## Repository inspection

Before implementation inspect:

1. Ruby and Rails versions and the resolved Active Record version.
2. ApplicationRecord inheritance and abstract classes.
3. Relevant model, schema, migrations, indexes, and constraints.
4. Associations and dependent behavior.
5. Validations and validation contexts.
6. Callbacks, especially transactional callbacks.
7. Scopes, default_scope, and relation extensions.
8. Existing query objects/services/repositories.
9. Factories/fixtures and test helpers.
10. Existing query/load behavior, including includes, preload, eager_load, and strict_loading.
11. Batch processing conventions.
12. Bulk write/delete/import conventions.
13. Observability/query logging and performance tooling.
14. Security or tenant-scoping conventions.
15. Neighboring models before introducing shared abstractions.

Never infer database semantics from model code alone.

## Model boundary

Use an Active Record model when the object represents persisted relational state and Active Record behavior is an actual consumer contract.

Keep the model cohesive:

- attributes and persisted behavior
- local domain predicates
- query scopes with explicit semantics
- lifecycle behavior that truly belongs to the record
- validation hooks owned by rails-validations.

Do not turn models into service containers, API clients, mailers, job schedulers, or authorization engines.

When a workflow coordinates multiple records, external systems, or several steps, prefer an application/domain service and keep each model responsible for its own persisted invariants.

## Relation semantics

Treat ActiveRecord::Relation as a lazy query description until a terminal operation/materialization occurs.

Review whether code:

- chains relations or accidentally turns them into Arrays
- triggers SQL earlier than expected
- reuses a relation after mutation or scoping
- changes ordering or grouping implicitly
- introduces joins that alter cardinality
- uses distinct/group/having intentionally
- returns model instances when scalar or projection data is enough.

Common terminal/materializing operations include loading records, iteration in many contexts, to_a, pluck, pick, count, and other query execution methods. Verify exact behavior against the resolved Rails version.

Prefer a relation as an internal query contract when callers need further composition. Return materialized values only when that is the intended API.

## Query composition

Build queries from explicit relation operations.

Review:

- where
- select
- reorder/order
- joins
- left_joins
- merge
- distinct
- group
- having
- limit/offset
- exists?
- calculations
- pluck/pick
- batch iteration.

Avoid string SQL when a structured relation API expresses the contract safely and clearly. When raw SQL is necessary, keep values parameterized and make adapter/version assumptions explicit.

Do not use Ruby-side filtering or sorting for datasets that should be filtered or ordered by the database unless the data set is deliberately small and that tradeoff is documented by repository evidence.

## Scopes and default_scope

Use scopes for named, composable query semantics that are unsurprising to callers.

A good scope:

- returns a relation
- has predictable composition behavior
- does not perform external side effects
- does not hide expensive work unexpectedly
- has a name describing its semantic filter or order.

Be cautious with default_scope. It silently participates in many relations and can affect both reads and record creation. Use explicit scopes when visibility or lifecycle rules must be obvious.

When changing default_scope:

- inspect every call site that assumes implicit filtering
- inspect creation defaults
- inspect unscoped callers
- verify tenant/security semantics
- add regression coverage for both scoped and unscoped behavior.

Never use default_scope as an authorization mechanism.

## Loading strategy

Choose the smallest loading strategy that matches the access pattern.

Distinguish:

- lazy association access
- preload
- eager_load
- includes
- joins
- strict loading.

Use eager loading/preloading when a real access pattern would otherwise issue repeated queries. Do not preload the entire object graph just in case.

Use strict loading when the repository wants accidental lazy association access to fail or when an explicit N+1 contract is valuable. Treat strict loading failures as evidence to fix the query boundary rather than disable the check indiscriminately.

Coordinate measured N+1/query cost with rails-performance.

## Projection and calculations

Avoid instantiating full Active Record objects when the caller only needs scalar data.

Use explicit projections such as pluck or pick when the contract is a scalar or array result.

Review the tradeoff:

- projected values do not carry model methods or callback behavior
- immediate materialization can prevent further relation composition
- custom attribute methods may not apply
- type casting must match the caller's expectations.

Never change a model query to pluck solely for perceived speed without verifying the consumer contract and measuring the workload when performance is material.

## Persistence lifecycle

Understand the distinction among:

- new in-memory record
- valid record
- persisted record
- saved record
- updated record
- destroyed record
- deleted row.

Before changing a write path, inspect which callbacks and validations execute and which direct methods intentionally bypass them.

Methods such as save, update, destroy, direct SQL updates/deletes, and bulk methods do not all provide the same lifecycle semantics.

Do not assume an in-memory object proves database state after a concurrent or independent write.

## Callbacks

Use Active Record callbacks only for lifecycle behavior intrinsically owned by the persisted record.

Good candidates can include small, deterministic normalization or lifecycle bookkeeping already consistent with repository conventions.

External side effects require particular care:

- prefer after_commit or after_rollback when the effect depends on transaction outcome
- understand that after_commit runs after persistence and cannot roll the transaction back
- preserve durable identity if the external operation can be retried
- avoid hidden network calls and large workflows in save callbacks.

Do not use callbacks to hide:

- multi-record application workflows
- authorization decisions
- unrelated integrations
- request-specific behavior
- job orchestration that belongs to an application boundary.

## Bulk writes and deletes

Distinguish object lifecycle methods from direct bulk operations.

Before using update_all, delete_all, destroy_all, import/upsert helpers, or adapter-specific bulk SQL, determine:

- validations
- callbacks
- timestamps
- dirty tracking
- association/dependent behavior
- returned values
- database constraint behavior
- audit/event semantics.

A bulk operation is not automatically equivalent to iterating through model instances.

Never replace destroy_all with delete_all just for speed without reviewing lifecycle, dependency, and audit contracts.

## Deletion semantics

Understand the difference between deleting a row and destroying a record through Active Record lifecycle.

Before changing deletion behavior inspect:

- dependent associations
- destroy callbacks
- soft-delete conventions
- database cascades
- auditing/events
- attachment cleanup
- authorization.

Keep irreversible side effects outside the model when their orchestration is broader than one record's lifecycle.

## Dirty and persistence state

Do not confuse attribute change tracking with persistence success.

When a feature depends on what changed, verify:

- when the change is observed
- whether the value was saved
- which callback phase runs
- whether a reload or fresh query is required
- whether another process can change the row independently.

Coordinate attribute/dirty protocol with Active Model and database transaction behavior with rails-database-engineering.

## Transactions and consistency

This skill reasons about Active Record transaction participation and lifecycle; rails-database-engineering owns deep transaction, locking, and isolation engineering.

When a write spans several Active Record calls, verify:

- which transaction owns them
- which callbacks fire before/after commit
- what external effects occur before or after commit
- whether retry can duplicate side effects
- whether failure leaves in-memory objects misleadingly changed.

Do not claim atomicity from a chain of model calls unless the actual transaction boundary proves it.

## Security and tenant scope

Active Record queries are not inherently authorized.

Review:

- tenant predicates
- authorization/policy boundary
- default_scope assumptions
- unscoped
- raw SQL
- dynamic column/order inputs
- IDs from external requests
- cross-tenant associations.

Do not use default_scope, model existence, or obscurity of an ID as an authorization mechanism.

Dynamic SQL identifiers require an explicit allowlist; values should remain parameterized.

## Performance and capacity

Review query shape and object allocation separately.

Look for:

- accidental full-table loads
- unnecessary model instantiation
- N+1 association access
- repeated COUNT/EXISTS queries
- unbounded batch jobs
- large to_a
- excessive callback fan-out
- duplicate loads caused by mixed preload/join usage.

Use evidence from rails-performance and rails-database-engineering before claiming improvement.

For large datasets, prefer bounded batch APIs such as find_each/find_in_batches where their ordering and concurrency semantics fit the workload.

## Testing

Choose tests that prove the Active Record contract:

- model lifecycle tests for callbacks/persistence semantics
- query tests for relation composition
- request/integration tests where controller behavior depends on query semantics
- integration tests for tenant/security boundaries
- query-count/performance tests when the repository already uses them.

For lifecycle changes, test both successful and failing paths.

For bulk operations, test which validations/callbacks are intentionally absent or present.

For strict loading, test that unintended lazy loading fails where that is the contract.

## Reference example

Deep Active Record work: composable scopes, strict loading to surface N+1, and a deliberate, commented bulk-write bypass.

```ruby
class Invoice < ApplicationRecord
  has_many :line_items, inverse_of: :invoice

  scope :unpaid, -> { where(paid_at: nil) }
  scope :overdue, ->(as_of: Date.current) { unpaid.where(due_on: ...as_of) }

  def self.account_digest(account)
    where(account_id: account.id)
      .includes(:line_items)   # eager load planned up front
      .strict_loading          # any unplanned lazy load raises instead of N+1-ing
      .map { |invoice| [invoice.reference, invoice.total_cents] }
  end
end

# Bulk writes skip the model lifecycle by contract; state that explicitly:
#   Invoice.insert_all!(rows, record_timestamps: true)  # no validations/callbacks
#   invoice.update_columns(paid_at: Time.current)       # deliberate callback bypass
```

## Agent review checklist

- [ ] Rails/Active Record version resolved
- [ ] model and ApplicationRecord boundary inspected
- [ ] schema/constraints checked
- [ ] relation laziness/materialization understood
- [ ] query composition preserves cardinality and ordering
- [ ] scope/default_scope semantics are explicit
- [ ] loading strategy is justified
- [ ] projection/materialization contract is correct
- [ ] persistence lifecycle is understood
- [ ] callbacks are intrinsically owned and scoped
- [ ] bulk operation semantics are explicit
- [ ] deletion semantics preserve dependents/audits
- [ ] dirty state is not confused with persistence
- [ ] transaction boundary is explicit
- [ ] tenant/authorization predicates are authoritative
- [ ] tests prove the relevant lifecycle/query contract
- [ ] performance claims have evidence when material

## Failure modes

Avoid:

- treating ActiveRecord::Relation as a plain Array before the contract requires materialization
- changing a composable relation into pluck prematurely
- adding default_scope for authorization
- disabling strict loading instead of fixing an N+1 boundary
- assuming callbacks run for bulk operations
- replacing destroy with delete for an unmeasured speed gain
- using model callbacks for multi-record workflows
- assuming after_save means the database transaction is committed
- assuming an in-memory model is current database truth
- forwarding dynamic order or column input directly into SQL
- claiming preload/eager loading improved performance without evidence
- hiding tenant predicates inside default_scope and treating that as complete authorization.

## Verification

Run, as applicable:

1. focused model/query tests
2. callback and lifecycle tests
3. request/integration tests for security-visible query changes
4. query-count or performance tests when material
5. schema/constraint checks for coupled persistence changes
6. bin/validate
7. branch CI.

Report actual verification evidence. Never infer Active Record behavior from a green unit test that does not exercise the relevant query/lifecycle boundary.

## Source foundation

Primary current Rails sources:

- Active Record Basics: https://guides.rubyonrails.org/active_record_basics.html
- Active Record Query Interface: https://guides.rubyonrails.org/active_record_querying.html
- Active Record Callbacks: https://guides.rubyonrails.org/active_record_callbacks.html
- Active Record Associations: https://guides.rubyonrails.org/association_basics.html
- Active Record Validations: https://guides.rubyonrails.org/active_record_validations.html

Current Rails documentation explicitly covers CRUD/model persistence, Relations, batch iteration, strict loading, scopes/default_scope, projections such as pluck, and transactional callbacks. Version-sensitive behavior must still be checked against the repository's resolved Rails version.

## Composition

This skill composes with rails-active-record, rails-associations, rails-validations, rails-active-model, rails-database-engineering, rails-performance, rails-security, rails-test-engineering, rails-test-engineering, ruby-clean-code, and ruby-tdd-refactoring.

## Routine model, migration, and query changes

_Merged from the retired `rails-active-record` skill._

### Repository inspection

Always inspect:

- schema.rb/structure.sql
- relevant migrations
- model
- associations
- validations
- callbacks
- scopes
- existing queries
- factories/fixtures
- tests
- indexes/constraints where visible

Never infer database behavior from the model file alone.

### Migrations

A migration describes a schema transition.

Review:

- column type
- nullability
- defaults
- foreign keys
- indexes
- uniqueness
- reversibility
- existing-data impact
- table size/production safety

Do not assume a migration is safe merely because it runs on an empty development database.

### Models

A model can contain behavior that naturally belongs to the persisted/domain record.

Do not turn it into a universal service container.

### Validations versus constraints

Model validation provides application-level feedback.

Database constraints provide stronger integrity guarantees, especially under concurrent writes.

For important invariants, consider both.

### Queries

Watch for:

- N+1 queries
- accidental full-table loads
- Ruby-side filtering that belongs in SQL
- unnecessary joins
- duplicate rows
- ambiguous ordering
- missing indexes
- large `.to_a`/materialization
- repeated queries inside loops

Choose SQL versus Ruby based on data volume, correctness, and repository conventions.

### Scopes

Use scopes when they are named, composable, and unsurprising.

Avoid scopes that hide large side effects or return surprising query shapes.

### Callbacks

Callbacks can make persistence side effects implicit.

Before adding one, ask whether an explicit application/domain workflow is clearer.

If callbacks already exist, map their lifecycle before refactoring.

### Transactions

Use the repository's transaction conventions when multiple persistence changes must succeed or fail together.

Do not assume external API calls participate in database transactions.

### Reference example

The routine path: a model with association and validation, SQL-side filtering, and a reversible migration with an index.

```ruby
class Invoice < ApplicationRecord
  belongs_to :customer, counter_cache: true
  has_many :line_items, dependent: :destroy

  validates :reference, presence: true, uniqueness: true
end

# Filter and order in SQL; Ruby-side filtering only for tiny, in-memory sets.
customer.invoices.where(paid: false).order(:due_on).limit(10)

class AddReferenceToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :reference, :string, null: false, default: ""
    add_index :invoices, :reference, unique: true
  end
end
```

### Agent review checklist

- [ ] schema inspected
- [ ] migration impact considered
- [ ] database constraints evaluated
- [ ] query plan/performance considered where material
- [ ] N+1 risk checked
- [ ] callback side effects mapped
- [ ] transaction boundary correct
- [ ] tests cover persistence behavior

### Verification

Run migration/schema checks and model/query tests. For performance-sensitive changes, inspect generated SQL/query counts and use the repository's profiling tools where available.

## Rails Active Record changes

For deep Active Record changes:
- inspect the resolved Rails/Active Record version, ApplicationRecord inheritance, model/schema/migrations, associations, validations, callbacks, scopes, default_scope, query consumers, loading conventions, bulk operations, security/tenant rules, performance evidence, and tests before implementation;
- classify the boundary as model ownership, Relation semantics, query composition, scope/default_scope, loading, persistence lifecycle, callbacks, bulk writes/deletes, or Active Record testing;
- keep rails-active-record focused on Active Record object/Relation semantics while delegating schema, indexes, constraints, transactions, locking, isolation, and query-plan mechanics to rails-database-engineering;
- treat ActiveRecord::Relation as a query description until an intended terminal/materializing operation; do not change a composable Relation into an Array or scalar result without preserving the caller contract;
- make ordering and cardinality explicit whenever a query is part of a contract; joins, distinct, grouping, and projections can change result shape;
- use scopes for composable named semantics and treat default_scope as high-risk implicit behavior; never use default_scope as an authorization mechanism;
- choose preload/includes/eager_load/joins/strict_loading from the actual consumer path; do not globally preload graphs or disable strict loading to silence regressions;
- use pluck/pick and other projections only when the caller actually needs scalar data; projection is a contract change, not a generic optimization;
- inspect the exact persistence method before changing it because validations, callbacks, timestamps, dirty state, and transactions differ across write APIs;
- use model callbacks only for lifecycle behavior intrinsic to the record; keep multi-record workflows, authorization, and external integrations outside callbacks;
- use after_commit or after_rollback when an effect depends on transaction outcome, and retain idempotency/correlation for retried external effects;
- do not assume bulk update/delete/import/upsert operations execute per-record validations or callbacks; review database constraints and audit/event semantics before using them;
- do not replace destroy_all with delete_all solely for speed; inspect dependent, callback, storage, auditing, and database-cascade behavior;
- do not treat in-memory model state as authoritative database state after independent or concurrent writes; reload or query authoritative state when required;
- keep tenant predicates and authorization authoritative outside hidden scope assumptions and review unscoped/raw SQL/dynamic identifiers as security boundaries;
- for large datasets, prefer bounded batch processing such as find_each/find_in_batches when their ordering and concurrency semantics fit the workload;
- test Relation type/composition, persistence success/failure, callback commit/rollback, bulk lifecycle, strict loading, deletion/dependents, and tenant boundaries at the owning test layer;
- never claim an Active Record query or loading optimization improved performance without query/runtime evidence.
