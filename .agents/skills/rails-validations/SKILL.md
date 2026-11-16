---
name: rails-validations
description: Use when implementing, reviewing, debugging, or testing Rails model validation contracts, validation contexts, error semantics, conditional rules, custom validators, database-backed invariants, or validation bypass paths.
---

# Rails Validations Engineering

## Purpose

Make validation behavior explicit, deterministic, and owned by the correct boundary.

This skill governs Rails Active Record and Active Model validation semantics. It covers validation lifecycle and bypass paths, built-in validator selection, validation contexts and conditions, associated validation, uniqueness versus database enforcement, custom validators, strict failures, structured ActiveModel::Errors contracts, validation callbacks, API/form error representation, security boundaries, performance, and deterministic tests.

Compose with rails-active-record for model/persistence semantics; rails-associations for relationship/autosave ownership; rails-active-model for non-persisted model-like objects; rails-database-engineering for constraints/indexes/transactions/locking; rails-action-controller for request input; rails-action-view and rails-i18n for form/translation behavior; rails-api-integration for API error contracts; rails-security for trust and authorization; rails-performance for validation-query cost; and rails-test-engineering/rails-test-engineering for verification.

Core boundary:

untrusted input
  -> casting/normalization
  -> semantic validation
  -> persistence/command
  -> database integrity

Validation is not authorization, not a transaction, and not a database constraint.

## Activate when

- adding or changing validates rules
- changing validate or validates_with
- introducing validation contexts
- adding conditional if/unless validation
- changing allow_nil, allow_blank, on, except_on, or strict
- changing validation error keys, types, details, messages, or JSON
- debugging valid?, invalid?, save, save!, create, or update behavior
- adding uniqueness or cross-record invariants
- validating associated records
- introducing a custom validator
- refactoring validation callbacks
- reviewing bulk/direct write paths
- changing form/API error rendering

Do not activate merely because a controller receives input. Use the owning request/input skill when no model validation contract changes.

## Repository inspection

Inspect before editing:

1. resolved Ruby/Rails versions and database adapter;
2. the model or Active Model object;
3. schema, migrations, nullability, indexes, foreign keys, and check/unique constraints;
4. association declarations and inverse/autosave behavior;
5. existing validations, custom validators, and validation callbacks;
6. callers using valid?, save, bang writes, or explicit validation contexts;
7. direct/bulk write paths such as insert_all, upsert_all, update_all, update_column, touch, or save(validate: false) where relevant;
8. controller/form/API error serialization;
9. translation keys and locale conventions;
10. existing model/request/system tests;
11. job/event/service entry points that mutate the same invariant;
12. performance evidence for validation queries or associated validation graphs.

Search for existing repository validation helpers before adding another abstraction.

## Boundary selection

### Model/application validation

Use validation when the rule describes whether an object is acceptable at that model/object boundary.

Examples include required fields, allowed value sets, comparable bounds, cross-attribute rules, state-dependent field requirements, and application-level uniqueness feedback.

### Database integrity

Use a database constraint when the invariant must survive concurrent writers, multiple application processes, direct database writers, or validation-bypassing operations.

A uniqueness validator improves feedback but does not create database uniqueness enforcement. Pair it with the required unique index/constraint when the invariant is authoritative.

### Authorization

Authorization answers whether an actor may perform an action against a resource. Never encode permission as ordinary validation.

### Workflow/orchestration

Do not use validation to send external requests, publish events, enqueue durable business work, mutate unrelated aggregates, coordinate multi-step workflows, or implement authorization policy.

## Validation lifecycle

Establish exactly which entry points run validation.

Rails normally runs validations before common persistence methods such as create, save, and update, while several direct/bulk write APIs bypass normal validation. save(validate: false) explicitly skips validation.

For each changed rule, answer:

- Is it always active?
- Is it create-only or update-only?
- Is a custom validation context used?
- Is it conditional?
- Can the write path bypass it?
- Does association validation invoke additional validators?
- Does persistence depend on database constraints after validation?

Never infer validation coverage from a model declaration alone.

## Built-in validator selection

Prefer the narrowest built-in validator that expresses the contract.

Common categories include absence, acceptance, confirmation, comparison, format, inclusion/exclusion, length, numericality, presence, uniqueness, validates_associated, validates_each, and validates_with.

Validator options include on, except_on, if, unless, allow_nil, allow_blank, strict, and message.

Do not stack overlapping validators merely for defensive appearance. Make the contract readable and test boundary cases.

### Presence and absence

Be explicit about nil, blank strings, false, empty collections, and absent associations.

Boolean requiredness should use boolean-appropriate inclusion/exclusion rules rather than presence, because false is blank in Rails.

For association presence, validate the association when the domain contract is about the related object rather than only its foreign-key column. Coordinate with rails-associations.

### Format

Use anchored formats when the entire string is the contract. Prefer absolute string anchors where appropriate. Keep format validation separate from normalization and parsing.

### Numericality and comparison

Define units, bounds, inclusivity, nilability, and coercion expectations. A successfully cast number is not automatically valid domain state.

## Optionality and conditional validation

Treat these as different decisions:

- allow_nil: skip when nil;
- allow_blank: skip when blank;
- if: run only when a predicate is true;
- unless: skip when a predicate is true;
- on: run in named contexts;
- except_on: exclude named contexts.

Rails supports symbol/proc/array-style conditional guards and validation contexts.

Prefer named predicate methods for non-trivial conditions so the rule is inspectable and testable. Keep inline procs for genuinely local predicates.

Avoid a large web of interacting conditions. If the validation matrix becomes workflow orchestration, move that workflow to a higher-level boundary.

## Validation contexts

Use a validation context only when the repository has a real operation/state boundary that differs from the default validation contract.

Prefer built-in create/update behavior when sufficient. Custom contexts should have explicit callers and focused tests.

For each custom context, document:

- who invokes the context;
- which rules are shared with default validation;
- which rules are context-specific;
- whether ordinary persistence still runs the required rules;
- how invalid state is reported.

Do not use custom contexts to make ordinary save silently accept invalid domain states.

## Validation errors

Treat ActiveModel::Errors as a structured contract, not merely a collection of display strings.

Relevant surfaces include error objects, errors[attribute], details, full_messages, full_messages_for, to_hash/as_json, add, base-level errors, and importing/merging errors.

Choose the representation from the consumer:

model/service tests -> error type/details
HTML form -> field association + human messages
API -> stable machine-readable field/type/details

Do not make API clients depend on human-readable prose when stable error identity can be exposed.

When changing errors, inspect locale files, form rendering, request/API serializers, client consumers, tests, and any metrics or logs that parse error keys.

Never expose secrets or internal query data through custom error messages.

## Custom validation methods

Use validate :method when the rule is small, local, and specific to one model.

A custom validation method should inspect state, add precise errors, avoid persistence, avoid external calls, avoid mutating unrelated records, and remain deterministic.

Use a custom validator class when the same coherent rule is genuinely reused across model types or needs a configurable contract.

ActiveModel::Validator and ActiveModel::EachValidator provide the reusable validator boundaries.

Do not create a validator class for one simple predicate merely to add indirection.

## Associated validation

Validate associated state only when the parent contract owns or requires that associated validity.

Coordinate with rails-associations for inverse, autosave, nested attributes, and lifecycle semantics.

Avoid recursively validating an unbounded object graph. Keep the graph narrow and test exact failure propagation.

## Uniqueness and concurrent invariants

Uniqueness validation is an application-level preflight check and can race under concurrent writes.

For authoritative uniqueness:

1. define the logical uniqueness key;
2. align application validation with normalized database values;
3. add or verify the database unique index/constraint;
4. decide how the application handles conflict errors;
5. test both friendly validation and authoritative conflict paths.

Scope, case sensitivity, collation, partial conditions, tenant keys, and normalization must agree across application and database semantics.

Do not normalize only inside validation when persistence identity depends on the normalized representation.

## Strict validations

Use strict validation only when invalid state should raise immediately and callers explicitly expect that exception boundary.

Strict validation raises ActiveModel::StrictValidationFailed by default or a configured exception class.

Before enabling strict behavior, inspect all callers and form/API error handling. Do not convert a user-correction path into an exception-only path accidentally.

## Validation callbacks

Treat before_validation and after_validation as lifecycle hooks, not as workflow engines.

Good uses can include deterministic normalization or preparation intrinsic to validation.

Avoid callbacks that send email, publish events, call external APIs, enqueue durable work, mutate unrelated aggregates, or implement authorization.

When a callback changes a value another validator observes, test ordering and the resulting validation state.

## Validation bypass paths

Audit direct/bulk writes whenever an invariant changes.

Examples include insert, insert_all, upsert, upsert_all, update_all, update_column, update_columns, touch, touch_all, counter-update methods, and save(validate: false).

The response is not to ban every bypass. Instead:

- identify the authoritative invariant;
- determine whether the writer is allowed to bypass application validation;
- move critical invariants to database constraints when necessary;
- document intentional exceptions;
- test the path independently.

## API, form, and controller integration

Keep request parsing outside model validation:

request boundary
  -> permitted/typed input
  -> model/domain validation
  -> application operation
  -> stable error representation

Controllers should not duplicate every model rule.

For APIs, map validation errors to the repository's stable schema and preserve machine-readable identity. For HTML forms, preserve field-level error associations and translation behavior.

## Performance

Validation can perform database queries and traverse associated objects.

Before optimizing:

1. measure query count and latency;
2. identify repeated or graph-wide validation;
3. measure representative inputs;
4. reduce unnecessary work without weakening the contract.

Do not memoize mutable validation state across persistence attempts unless lifecycle/reset semantics are explicit.

## Security and tenant isolation

Validation does not establish authorization.

Review:

- tenant keys in uniqueness scopes;
- resource authorization before validation of private records;
- user-controlled values used in validator queries;
- dynamic constantization in custom validators;
- error-message disclosure;
- existence-check behavior for sensitive resources;
- API error representation across tenants.

Never turn “record exists” or “value is unique” into an authorization decision.

## Implementation procedure

1. Resolve Rails/Ruby/adapter versions.
2. Identify the invariant and the boundary that owns it.
3. Inspect model, schema, indexes/constraints, associations, callbacks, write paths, callers, and tests.
4. Classify the rule as validation, database integrity, authorization, or workflow.
5. Select the narrowest built-in validator or justified custom validator.
6. Define optionality, context, conditions, and error identity.
7. Add/update database enforcement for concurrent authoritative invariants.
8. Audit validation-bypassing write paths.
9. Integrate errors with the actual form/API consumer.
10. Add focused boundary and conflict/failure tests.
11. Run repository validators and relevant Rails tests.
12. Inspect the final diff for duplicate rules, hidden side effects, and accidental error-contract changes.

## Failure modes

Watch for:

- using valid? as proof that persistence will always satisfy an invariant;
- using model validation as authorization;
- using validation contexts to silently weaken normal saves;
- relying on uniqueness validation without database enforcement;
- confusing nil, blank, false, and empty collection semantics;
- conditions that encode workflow or authorization;
- reusable validators that are actually one-off predicates;
- custom validators that perform I/O;
- strict validation where callers expect ordinary errors;
- human error strings treated as stable machine APIs;
- validation of huge association graphs;
- duplicate rules across controller, model, service, and database with different semantics;
- bulk write paths that bypass the only protection;
- validation callbacks with external side effects.

## Reference example

A reusable each-validator with an I18n-ready error key, plus an invariant the database constraint ultimately enforces.

```ruby
class CurrencyValidator < ActiveModel::EachValidator
  SUPPORTED = %w[usd eur gbp].freeze

  def validate_each(record, attribute, value)
    return if value.nil? # presence is a separate, explicit validation

    record.errors.add(attribute, :unsupported_currency, value: value) unless SUPPORTED.include?(value)
  end
end

class Invoice < ApplicationRecord
  validates :currency, currency: true, presence: true

  validate :due_on_is_future

  private

  def due_on_is_future
    return if due_on.blank? || due_on > Date.current

    errors.add(:due_on, "must be in the future")
  end
end

# The database check constraint remains the last line of defense under
# concurrent writers; model validation is feedback, not the guarantee.
```

## Agent review checklist

- [ ] rule owner is explicit
- [ ] runtime/version is resolved
- [ ] all relevant write paths are inspected
- [ ] nil/blank/false/boundary semantics are intentional
- [ ] context and condition semantics are explicit
- [ ] custom validator is justified
- [ ] strict failure behavior is intentional
- [ ] error keys/types/details/messages preserve the consumer contract
- [ ] authoritative uniqueness has database enforcement when required
- [ ] associated validation scope is bounded
- [ ] validation callbacks have no hidden workflow or external side effects
- [ ] authorization is not delegated to validation
- [ ] bypass paths are intentional
- [ ] deterministic tests cover the changed contract
- [ ] no unmeasured performance claim is introduced

## Verification

Verify at the owning boundary:

- valid and invalid state;
- nil/blank/false edge cases;
- create/update differences;
- custom contexts;
- conditional branches;
- strict failures when applicable;
- error type/details and rendered or wire representation;
- database conflict behavior for authoritative invariants;
- associated validation failure;
- bypass write behavior;
- deterministic repeated execution.

Run bin/validate and focused validation/system tests. For persistence invariants, include database-level verification through rails-database-engineering.

## Related skills

- rails-active-record
- rails-associations
- rails-active-model
- rails-database-engineering
- rails-action-controller
- rails-action-view
- rails-api-integration
- rails-i18n
- rails-security
- rails-performance
- rails-test-engineering

## Source foundation

This skill synthesizes the repository's existing validation guidance with The Ruby Workshop and Clean Ruby, and is grounded in the current Rails Active Record Validations and Active Model validation/error documentation. The current Rails guide documents validator semantics, lifecycle triggers and bypasses, conditional and strict validation, custom validators, and validation errors.

## Primary Rails references

- https://guides.rubyonrails.org/active_record_validations.html
- https://api.rubyonrails.org/classes/ActiveModel/Validations/ClassMethods.html
- https://api.rubyonrails.org/classes/ActiveModel/Errors.html

## Rails Validations changes

For deep Rails validation changes:
- inspect resolved Rails/Ruby/adapter versions, model/object definition, schema constraints, indexes, associations, callbacks, validation contexts, custom validators, error consumers, direct/bulk write paths, and tests;
- classify the boundary as lifecycle, validator semantics, condition/context, error contract, association validation, uniqueness/invariant enforcement, custom validator, strict failure, validation callback, or bypass path;
- keep ownership explicit: model validation answers whether state is acceptable at that boundary; database constraints own invariants that must survive concurrency and alternate writers;
- never use validation as authorization, tenant access control, transaction orchestration, external API success handling, or durable workflow;
- inspect all relevant write APIs because direct/bulk operations can bypass validations; use rails-database-engineering for authoritative constraints;
- treat on, except_on, if, unless, allow_nil, allow_blank, and strict as explicit contract choices and test their interactions;
- use custom validation contexts only for named operations with explicit callers; do not make ordinary save silently accept invalid domain state;
- prefer the narrowest built-in validator and justify reusable validator classes;
- keep validation callbacks local and deterministic; never hide external effects, authorization, or multi-step workflow in them;
- treat ActiveModel::Errors as a structured contract and preserve attribute/type/detail identity;
- keep associated validation graphs bounded and coordinate with inverse/autosave/nested-persistence ownership;
- pair application uniqueness validation with database enforcement when the invariant is authoritative, including tenant/scope/normalization semantics;
- use strict validation only when callers explicitly expect fail-fast exceptions;
- test lifecycle, contexts, conditions, error shape, persistence conflicts, associated failures, and bypass writers at their owning boundaries;
- treat direct/bulk writers as a validation bypass audit surface and make intentional validation bypasses explicit;
- never claim validation safety from valid? alone when alternate writers or database-level enforcement matter.
