---
name: authorization-decision-boundary
description: Authorization Decision Boundary
family: security
---
# Authorization Decision Boundary

## Problem
Different entry points make independent permission decisions for the same operation.

## Use when
The same protected action has controller, service, job, API, or task callers.

## Do not use when
Unrelated operations with independent policy and no shared side effect.

## Repository inspection
Inspect all callers and policy/ability classes.

## Implementation procedure
Choose one authoritative decision boundary and adapt each execution surface to it.

## Example

```ruby
# One decision, used by every entry point that performs the operation.
class InvoicePolicy
  def initialize(user, invoice)
    @user = user
    @invoice = invoice
  end

  def void? = @user.accountant_of?(@invoice.account) && @invoice.unpaid?
end

class InvoicesController < ApplicationController
  def void
    invoice = current_account.invoices.find(params[:id])
    return head :forbidden unless InvoicePolicy.new(current_user, invoice).void?

    Invoices::Void.call(invoice)
  end
end

class Api::InvoicesController < Api::BaseController
  def void
    invoice = current_account.invoices.find(params[:id])
    return head :forbidden unless InvoicePolicy.new(current_token.user, invoice).void? # same policy
    Invoices::Void.call(invoice)
  end
end
```

## Failure modes
Policy drift, contradictory decisions, bypass through alternate caller.

## Testing
Test the shared decision and representative entry points.

## Review checklist
[ ] one authoritative decision [ ] adapters explicit [ ] no duplicate policy

## Related skills
rails-cross-boundary-authorization-security, rails-authorization