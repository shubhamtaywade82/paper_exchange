---
name: scaffold-lifecycle
description: Use when using a Rails scaffold or generator as a starting point and then shaping the generated code into the actual application architecture.
family: rails
---

# Rails Scaffold Lifecycle

## Problem

Generated CRUD code is useful for bootstrapping a resource, but it is not automatically the final architecture.

## Use when

- starting a conventional resource from scaffold/generator output
- reviewing generated code
- removing unused scaffold behavior after requirements are known

## Do not use when

- the repository already has a stable handcrafted resource pattern
- the generated structure does not match the intended feature
- the generator would overwrite important custom code

## Repository inspection

Inspect Rails version, generator output, existing resource conventions, test framework, routes, schema conventions, and current authorization patterns.

## Implementation procedure

1. generate only when the generated shape matches the task
2. review the generated migration and schema effect
3. inspect model, associations, and validations
4. inspect controller, actions, and params
5. inspect routes and views/forms
6. remove unused actions/files/routes
7. align tests with actual contracts
8. verify the complete diff

## Example

```bash
# Generate, then immediately bring it to the application's conventions.
bin/rails generate scaffold Article title:string body:text account:references --no-jbuilder

# After generation (same PR):
#  - scope find/new/create through Current.account and add authorization
#  - replace params.require.permit with the app's params.expect convention
#  - add null: false / foreign key / index constraints to the migration
#  - delete unused actions and views (e.g. edit/update if articles are immutable)
#  - replace the generated fixture/tests with behavior tests for the real contract
bin/rails db:migrate && bin/rails test test/controllers/articles_controller_test.rb
```

## Failure modes

- keeping every generated action forever
- shipping placeholder text or comments
- accidental destructive file replacement
- exposing scaffold routes without authorization
- treating generated code as architecture rather than a draft

## Testing

Run the generated/affected tests after cleanup. Add request/system coverage for the actual user-facing resource contract.

## Review checklist

- [ ] generator output reviewed
- [ ] schema/migration intentional
- [ ] unnecessary artifacts removed
- [ ] routes match requirements
- [ ] authn/authz preserved
- [ ] tests cover the post-scaffold design

## Related skills

- rails-generators
- rails-routing
- rails-action-controller
- rails-test-engineering
- rails-architecture
