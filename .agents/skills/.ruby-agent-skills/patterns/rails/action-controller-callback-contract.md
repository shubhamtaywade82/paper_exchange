---
name: action-controller-callback-contract
description: Use when adding or reviewing before_action, after_action, or around_action behavior.
family: rails
---

# Action Controller Callback Contract

## Problem

Controller callbacks can hide execution order, scope, database work, and response halting behind inherited configuration.

## Use when

- adding a callback
- narrowing or expanding callback scope
- debugging callback order
- moving authentication/resource loading into a callback.

## Do not use when

- behavior is a one-off action step
- the callback would contain a business workflow.

## Repository inspection

Inspect ApplicationController, inherited concerns, callback declarations, only/except scopes, order, and request tests.

## Implementation procedure

1. Name the request prerequisite.
2. Keep the callback small and deterministic.
3. Scope it to the smallest action set.
4. Document what state it establishes or what response it may produce.
5. Keep business workflows in services/domain objects.
6. Add tests for affected and unaffected actions.

## Example

```ruby
class InvoicesController < ApplicationController
  # Callbacks are action-scoped and do one prerequisite each; order is explicit.
  before_action :require_login
  before_action :set_invoice, only: %i[show update destroy]
  before_action :authorize_invoice!, only: %i[update destroy]

  def update
    @invoice.update!(invoice_params)
    redirect_to @invoice
  end

  private

  def set_invoice
    @invoice = current_account.invoices.find(params[:id])
  end

  def authorize_invoice!
    head :forbidden unless InvoicePolicy.new(current_user, @invoice).update?
  end

  def invoice_params = params.expect(invoice: [:due_on, :notes])
end
```

## Failure modes

- global callback for a local need
- hidden external calls in before_action
- loading records before authorization
- order-dependent callback chains with no tests
- using after_action for correctness-critical persistence.

## Testing

Test callback execution order only when order is contractual; otherwise test observable request behavior. Test skipped/public actions explicitly.

## Review checklist

- [ ] smallest scope
- [ ] execution order understood
- [ ] halting behavior explicit
- [ ] no hidden business workflow
- [ ] unaffected actions remain unaffected

## Related skills

rails-action-controller, rails-authentication, rails-active-support
