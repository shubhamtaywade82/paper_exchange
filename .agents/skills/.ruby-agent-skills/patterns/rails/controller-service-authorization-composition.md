---
name: controller-service-authorization-composition
description: Controller and Service Authorization Composition
family: security
---
# Controller and Service Authorization Composition

## Problem
A controller may authorize correctly while direct service callers bypass the same rule.

## Use when
A service can be called by jobs, tasks, events, or multiple controllers.

## Do not use when
A service is purely internal and has an enforced single trusted caller contract.

## Repository inspection
Inspect service callers, policy mechanism, command interfaces, and tests.

## Implementation procedure
Authorize the application operation at the service boundary or require an explicit authorized capability/context.

## Example

```ruby
# The controller authorizes for the HTTP surface; the service authorizes
# again because jobs and the API also call it.
class InvoicesController < ApplicationController
  def refund
    invoice = current_account.invoices.find(params[:id])
    authorize invoice, :refund?
    Invoices::Refund.call(invoice, actor: current_user)
    redirect_to invoice
  end
end

class Invoices::Refund
  def self.call(invoice, actor:)
    raise Pundit::NotAuthorizedError unless InvoicePolicy.new(actor, invoice).refund?

    invoice.refunds.create!(amount_cents: invoice.total_cents, actor: actor)
  end
end
```

## Failure modes
Direct bypass, ambient current user, duplicate conflicting checks.

## Testing
Invoke the service directly and through each public caller.

## Review checklist
[ ] direct call secured [ ] capability explicit [ ] parity tested

## Related skills
rails-cross-boundary-authorization-security, rails-authorization