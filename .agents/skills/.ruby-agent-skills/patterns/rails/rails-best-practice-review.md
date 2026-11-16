---
name: rails-best-practice-review
description: Review Rails code-quality findings against the actual repository and Rails version.
family: rails-quality
---

# Rails Best-Practice Review

## Problem
A Rails code-quality analyzer reports findings, or a change needs a systematic Rails architecture review.

## Use when
- performing a Rails quality review
- interpreting rails_best_practices output
- reviewing routes, models, controllers, views, helpers, or migrations
- deciding whether a warning requires a change

## Do not use when
- the task is pure Ruby
- a more specific repository pattern completely covers the concern

## Repository inspection
Inspect Rails/Ruby versions, relevant files, tests, schema/migrations, routes, existing patterns, and rails_best_practices configuration.

## Procedure
1. Inspect the analyzer finding.
2. Map it to the underlying design concern.
3. Check repository conventions and contract.
4. Determine whether it is correctness, maintainability, performance/integrity, outdated, or intentional.
5. Select the smallest justified change.
6. Add/update focused tests.
7. Re-run the analyzer or document why it is not applicable.
8. Inspect the final diff.

## Implementation procedure

1. Inspect the finding and surrounding Rails code.
2. Resolve Rails/Ruby version and repository conventions.
3. Classify the finding as correctness, maintainability, performance/integrity, outdated, or intentional.
4. Apply the smallest justified change.
5. Run focused tests and the applicable analyzer.
6. Review the final diff.

## Example

```markdown
## Review: `OrdersController#create` (PR #412)

| # | Finding                                                   | Evidence                          | Severity | Action                         |
|---|-----------------------------------------------------------|-----------------------------------|----------|--------------------------------|
| 1 | Loads order by id without account scope (IDOR)            | `Order.find(params[:id])` L18     | high     | `Current.account.orders.find`  |
| 2 | `after_save :charge_card` makes an HTTP call in a callback| `app/models/order.rb:22`          | high     | explicit call after commit     |
| 3 | Missing index for `orders.account_id` lookup              | `db/schema.rb` has none           | medium   | concurrent index migration     |
| 4 | Non-RESTful `post :do_cancel`                              | `config/routes.rb:31`             | low      | `resource :cancellation`       |

Not reported: style-only offenses already covered by RuboCop.
```

## Failure modes
- blindly fixing every warning
- introducing deprecated Rails APIs
- moving logic merely to satisfy a linter
- deleting methods without checking dynamic callers
- adding abstractions without a real responsibility
- suppressing findings without justification

## Testing
Test observable behavior affected by the finding. For route/controller/model changes, use the repository's appropriate request/model/integration coverage.

## Review checklist
- [ ] finding understood
- [ ] modern Rails compatibility checked
- [ ] contract preserved
- [ ] fix justified
- [ ] no unnecessary abstraction
- [ ] tests updated
- [ ] analyzer re-run or exception documented

## Related skills
- rails-architecture
- rails-routing
- rails-action-controller
- rails-active-record
- rails-action-view
- rails-test-engineering