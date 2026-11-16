---
name: rails-associations
description: Use when designing or reviewing deep Active Record association contracts including cardinality, ownership, inverse relationships, through joins, polymorphism, dependent lifecycle, autosave, counters, touch, callbacks, and association testing.
---

# Rails Associations

## Purpose

Treat Active Record associations as executable relationship contracts, not merely convenience methods.

An association defines how records are connected, how foreign keys are interpreted, how objects are traversed and mutated, and what lifecycle behavior occurs when records are added, removed, destroyed, or saved.

This skill deepens the foundational association guidance. Active Record query semantics belong to rails-active-record; schema constraints, foreign keys, indexes, transactions, locks, and migrations belong to rails-database-engineering.

## Activate when

- adding or changing belongs_to, has_one, has_many, has_many :through, or HABTM
- changing association options such as class_name, foreign_key, primary_key, inverse_of, source, or source_type
- marking or migrating away from deprecated Active Record associations
- introducing polymorphic associations
- changing dependent behavior
- changing association creation/removal or collection mutation
- changing autosave, inverse, validation, counter cache, or touch behavior
- adding association callbacks or extensions
- debugging missing, duplicated, stale, or unexpectedly saved associated records
- reviewing N+1 behavior caused by association traversal
- changing join-model ownership in a through association
- changing association tests or fixtures/factories around relationship semantics

## Boundary ownership

| Concern | Primary owner |
|---|---|
| Association cardinality and object relationship | rails-associations |
| Relation/query composition and materialization | rails-active-record |
| Foreign keys, indexes, constraints, migrations | rails-database-engineering |
| Validation/error semantics | rails-validations |
| Authorization/tenant scope | rails-security |
| File attachment lifecycle | rails-active-storage |
| Background association deletion | rails-active-job |
| Query cost/N+1 measurement | rails-performance |
| Non-persisted model relationships | rails-active-model |

An association does not itself establish authorization, database integrity, or business workflow ownership.

## Repository inspection

Before changing an association inspect:

1. Ruby and Rails versions.
2. Both sides of the relationship.
3. Actual foreign-key columns and primary keys.
4. Nullability, indexes, uniqueness, and foreign keys.
5. Existing association options and scopes.
6. Validation and callback behavior.
7. Dependent behavior and database cascades.
8. Existing through/join models.
9. Polymorphic type columns and allowed classes where applicable.
10. Existing inverse_of/autoloading conventions.
11. Factory/fixture construction paths.
12. Query/loading paths and strict-loading expectations.
13. Tenant and authorization boundaries.
14. Cleanup/audit/event behavior.
15. Tests that exercise creation, mutation, deletion, and loading.

Inspect both directions. A change that looks local in one model can change generated methods, autosave, validation, or deletion semantics on the other side.

## Cardinality and ownership

Choose the association from the database/domain ownership, not from method-name convenience.

Typical contracts:

- belongs_to: the foreign key is held by the declaring record
- has_one: one associated record is expected from the declaring side
- has_many: the associated table can reference many records
- has_many :through: traversal and optional join-model behavior are explicit
- has_one :through: singular traversal through an intermediate association
- HABTM: direct many-to-many where a join model carries no domain behavior.

For every relationship state:

- state expected cardinality
- identify foreign-key ownership
- determine whether absence is valid
- determine whether uniqueness is required
- determine whether the database enforces the relationship.

Do not model one-to-one semantics with has_one alone when the database permits multiple child rows.

## belongs_to contract

A belongs_to association expresses that the declaring row references another record.

Review:

- required versus optional relationship
- foreign key name/type
- primary key when nonstandard
- database foreign key
- validation semantics
- inverse association
- authorization of referenced records.

Do not assume belongs_to validation replaces a database foreign key. Application validation and database referential integrity protect different failure paths.

When optional: true is required, explicitly reason about what NULL means and what happens when a non-NULL foreign key points to a missing row.

## has_one and uniqueness

A has_one declaration describes expected cardinality, but it does not by itself guarantee database uniqueness.

When exactly one child is required:

1. define the association
2. inspect/create the corresponding foreign key
3. enforce uniqueness where the database contract requires it
4. test duplicate creation under concurrent or independent writes.

Do not rely on a model association to prevent two rows from referencing the same owner.

## has_many collection semantics

A has_many association exposes a collection API with add, remove, clear, build, create, and assignment behavior.

Before changing collection mutation, establish:

- whether add saves immediately
- whether build leaves records unsaved
- what happens to removed members
- which callbacks/validations execute
- how dependent behavior interacts with collection methods
- whether the collection is loaded or query-backed.

Do not infer collection mutation semantics from ordinary Array behavior.

Test add, remove, replace/assignment, clear, unsaved parent, and persisted parent scenarios when they are contractual.

## Through associations

Use has_many :through when the intermediate relationship is meaningful or already exists.

Inspect the join model's:

- belongs_to associations
- validations
- uniqueness constraints
- additional attributes
- callbacks
- authorization/tenant ownership
- lifecycle.

For writable through associations, explicitly determine what Rails creates or removes in the join table when assigning or mutating the association.

Remember that deleting/replacing through join records is not necessarily equivalent to destroying the target records. The current Rails guide notes that automatic deletion of join models can be direct and does not invoke destroy callbacks.

Avoid HABTM when the join itself carries domain attributes or behavior. Prefer a join model so those semantics have an explicit owner.

## Polymorphic associations

Polymorphism stores both an identifier and a type discriminator.

Before adding or changing polymorphism define:

- allowed target classes
- tenant/security ownership
- type naming/stability
- foreign-key/index strategy
- deletion behavior
- serialization/API exposure
- migration strategy if class names change.

Do not accept arbitrary client-provided polymorphic type names for constantization or lookup.

Treat the type column as untrusted data at external boundaries and use an explicit allowlist in application code where it crosses a trust boundary.

## Inverse associations

Bidirectional recognition can affect:

- duplicate queries
- object identity in memory
- autosave
- validation of associated records
- building child records through parent associations.

Use inverse_of explicitly when automatic inference is not reliable, especially when using custom class_name, foreign_key, through relationships, or scopes.

Audit both sides whenever an association name, foreign key, or scope changes.

Do not add inverse_of blindly to every association. Verify that the relationship is genuinely bidirectional and that the local Rails version supports the declaration.

## Autosave and nested persistence

Understand which associated records are automatically saved as part of parent persistence.

Review:

- new versus existing associated records
- validation behavior
- autosave
- nested attributes if present
- transaction ownership
- rollback behavior.

Do not assume every associated change is persisted just because the parent is saved.

Do not introduce autosave simply to make a form work. Define which object owns the write workflow and test the failure path.

## Dependent lifecycle

dependent options are lifecycle contracts, not cleanup decorations.

Before changing dependent behavior review:

- destroy callbacks
- database ON DELETE behavior
- foreign key nullability
- storage attachments
- audit/events
- soft deletion
- tenant boundaries
- request latency or asynchronous work.

Important distinctions include destroy, delete, nullify, restrict_with_exception, restrict_with_error, and asynchronous destruction where supported by the resolved Rails version.

Do not combine database cascading and application destruction callbacks without proving their combined semantics.

For asynchronous dependent destruction, verify the queue/runtime contract and whether database foreign keys are compatible with the chosen mode. Current Rails documentation explicitly warns about combining asynchronous association destruction with foreign-key constraints.

## Counter caches and touch

counter_cache and touch create denormalized lifecycle coupling.

Before using counter_cache:

- identify the authoritative count
- define how records are added/removed
- review backfill/reconciliation requirements
- consider concurrent updates and repair strategy.

Before using touch:

- identify which timestamp drives caches or clients
- verify write amplification
- review callback/commit behavior
- avoid turning incidental child updates into broad cache invalidation storms.

Do not treat counter caches or timestamps as the sole source of truth when correctness requires querying authoritative data.

## Association callbacks

Association callbacks include before_add, after_add, before_remove, and after_remove.

Use them only for narrow collection lifecycle behavior intrinsic to the association.

For each callback review:

- which mutation methods trigger it
- whether it can halt the mutation
- transaction scope
- side effects
- retry/idempotency
- behavior during bulk or direct database operations.

Do not use association callbacks for multi-record workflows, external API calls, authorization engines, or background job orchestration.

## Association extensions

Association extensions can add domain-specific methods to the association proxy.

Use them only when the behavior is truly relationship-scoped and remains query/object-boundary behavior.

Keep extension methods deterministic and avoid hidden network/database workflows beyond the query operation they clearly represent.

## Loading and inverse-aware performance

Association traversal is a frequent source of N+1 queries.

Before optimizing:

1. identify the actual traversal path
2. inspect whether inverse recognition removes duplicate loads
3. choose preload/includes/eager_load only for the demonstrated path
4. use strict loading where accidental lazy loading should be prohibited
5. measure query count and object allocation.

Do not solve an N+1 by globally preloading every association.

## Security and tenant isolation

Associations do not authorize access.

Review:

- tenant ownership across both sides
- cross-tenant foreign keys
- polymorphic targets
- through joins
- collection assignment
- direct ID-based association creation
- unscoped association access.

A valid association can still cross a security boundary.

Authorization belongs to rails-security or the application's policy boundary. Database ownership/integrity belongs to rails-database-engineering.

## Performance and capacity

Association design affects:

- query count
- row cardinality
- object allocation
- write amplification
- delete fan-out
- callback execution
- asynchronous job volume.

Measure before changing association shape for performance.

Large collections should use bounded query/batch behavior rather than materializing every associated record. Compose with rails-active-record and rails-performance.

## Testing

Test the relationship contract, not merely that Rails accepts the declaration.

Where applicable test:

- cardinality
- required/optional belongs_to
- foreign-key integrity
- uniqueness for has_one semantics
- collection build/create/add/remove/clear
- through join creation/removal
- polymorphic allowed types
- inverse behavior
- autosave success/failure
- dependent destroy/delete/restrict/nullify
- counter cache and touch behavior
- association callbacks
- tenant/authorization boundaries
- representative loading/N+1 paths.

Prefer behavior tests over brittle assertions on generated method names.

## Reference example

Associations declared with inverse_of and counter_cache, including a distinct through-association for a many-to-many read.

```ruby
class Clinic < ApplicationRecord
  has_many :appointments
  has_many :patients, -> { distinct }, through: :appointments
  has_one :address, as: :addressable, dependent: :destroy
end

class Appointment < ApplicationRecord
  belongs_to :clinic, inverse_of: :appointments
  belongs_to :patient, counter_cache: true
end

class Patient < ApplicationRecord
  has_many :appointments
  has_many :clinics, through: :appointments
end

# inverse_of keeps both in-memory sides coherent:
#   clinic.appointments.build(patient: patient).patient.clinic == clinic  # => true
```

## Agent review checklist

- [ ] both association directions inspected
- [ ] cardinality is explicit
- [ ] foreign-key ownership is correct
- [ ] database integrity complements the association
- [ ] through/join ownership is explicit
- [ ] polymorphic classes are bounded
- [ ] inverse behavior is understood
- [ ] autosave semantics are intentional
- [ ] dependent lifecycle is explicit
- [ ] counter/touch coupling is justified
- [ ] association callbacks are narrow
- [ ] loading behavior is measured
- [ ] tenant/security ownership is authoritative
- [ ] relationship mutations are tested
- [ ] deletion and failure paths are tested

## Failure modes

Avoid:

- using has_one without database uniqueness when one-to-one is a hard invariant
- treating association declarations as foreign-key constraints
- choosing HABTM when the join has domain behavior
- accepting arbitrary polymorphic type names
- assuming through-association changes destroy target records
- adding inverse_of without verifying both directions
- assuming parent save persists every associated change
- using dependent callbacks and database cascades without combined-lifecycle analysis
- using counter_cache or touch as an authoritative business source
- putting external side effects in association callbacks
- globally eager-loading associations to mask N+1 problems
- assuming an association proves tenant authorization.

## Verification

Run, as applicable:

1. focused association/model tests
2. schema and foreign-key/index checks
3. query/loading tests for representative traversal
4. authorization/tenant regression tests
5. dependent/delete lifecycle tests
6. autosave/transaction failure tests
7. counter/touch reconciliation tests when used
8. bin/validate
9. branch CI.

Report actual verification evidence; never infer relationship correctness from a passing model boot.

## Rails 8.1 current framework considerations

- Rails 8.1 supports deprecated Active Record associations with reporting modes such as warning, raising, or notification.
- Use association deprecation as migration evidence: identify callers, transition them to the replacement contract, and remove the deprecated boundary only after usage is eliminated.

## Source foundation

Primary current Rails source:

- Active Record Associations Guide: https://guides.rubyonrails.org/association_basics.html

The current guide documents association cardinality, foreign-key integrity, collection mutation methods, through associations, bidirectional/inverse behavior, dependent options, validation, callbacks, association extensions, and association options.

Version-sensitive behavior must be resolved against the repository's actual Rails version.

## Composition

This skill composes with rails-active-record, rails-database-engineering, rails-validations, rails-security, rails-active-job, rails-active-storage, rails-performance, rails-test-engineering, rails-test-engineering, rails-zeitwerk, ruby-clean-code, and ruby-tdd-refactoring.

## Rails Associations changes

For deep Active Record association changes:
- inspect the Rails version, both association directions, foreign-key columns, primary keys, nullability, uniqueness, database foreign keys, scopes, inverse_of, dependent options, callbacks, through/join models, polymorphic types, autosave, counter/touch behavior, tenant ownership, loading paths, and relationship tests before implementation;
- classify the boundary as cardinality/ownership, collection mutation, through join, polymorphic target, inverse/autosave, dependent lifecycle, counter/touch, association callback, loading, or association testing;
- do not infer database integrity from association declarations; use rails-database-engineering for foreign keys, unique constraints, indexes, nullability, and transaction/locking mechanics;
- when has_one means exactly one row, verify database uniqueness rather than relying only on the association declaration;
- keep belongs_to presence/optional semantics aligned with the actual foreign-key and domain contract;
- inspect both sides of every changed relationship; custom foreign_key, class_name, scopes, and through associations can affect inverse inference, autosave, validation, and duplicate queries;
- use inverse_of explicitly when automatic inverse detection is not reliable and verify the resulting identity/autosave behavior;
- treat has_many :through as a join-model contract; do not assume changing a through collection destroys target records;
- prefer a join model over HABTM when the relationship carries attributes, validations, callbacks, authorization, or lifecycle behavior;
- restrict polymorphic target types to an explicit allowed set and never trust client-provided type names for arbitrary constantization;
- treat dependent as lifecycle behavior that must be reconciled with database cascading, foreign-key nullability, attachment cleanup, audits, and transaction boundaries;
- verify asynchronous dependent destruction against the actual Active Job/runtime and database foreign-key contract;
- make autosave/nested persistence ownership explicit; test parent success/failure and associated-record validation failures;
- treat counter_cache and touch as denormalized coupling requiring authoritative-source and reconciliation reasoning;
- keep before_add/after_add/before_remove/after_remove callbacks narrow and deterministic; do not hide external workflows or authorization engines inside them;
- choose association loading from the actual traversal path; review inverse behavior before adding broad eager loading and compose with rails-active-record strict-loading/query guidance;
- keep association validity separate from authorization and tenant isolation; a valid relationship can still cross a security boundary;
- test cardinality, both directions, collection mutation, through changes, polymorphic targets, dependent behavior, autosave failure, security isolation, and representative loading behavior;
- never claim association-performance improvements without measured query/runtime evidence.
