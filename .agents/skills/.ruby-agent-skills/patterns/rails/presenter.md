---
name: presenter
description: A presentation-focused object that transforms domain data for a view or response.
family: rails
---

# Presenter

## Problem

A presentation-focused object that transforms domain data for a view or response.

## Use when

Use when view formatting or presentation decisions become substantial and reusable.

## Do not use when

Do not use for trivial one-line formatting that belongs naturally in a view/helper.

## Repository inspection

Inspect existing objects that solve the same responsibility, naming and namespace conventions, construction boundaries, tests, and framework-specific conventions before introducing this pattern.

## Implementation procedure

1. Identify the responsibility and public contract.
2. Search the repository for an existing implementation or equivalent abstraction.
3. Define the smallest interface that solves the problem.
4. Keep collaborators explicit and follow local construction conventions.
5. Preserve existing behavior while introducing the boundary.
6. Add focused tests for the contract and important failure cases.
7. Remove duplication only after behavior is covered.
8. Inspect the final diff for unnecessary indirection.

## Example

```ruby
class InvoicePresenter
  include ActionView::Helpers::NumberHelper

  def initialize(invoice) = @invoice = invoice

  def total = number_to_currency(@invoice.total_cents / 100.0, unit: "₹")
  def status_label = I18n.t("invoices.status.#{@invoice.status}")
  def overdue? = @invoice.unpaid? && @invoice.due_on < Date.current

  def css_class
    return "invoice--overdue" if overdue?
    @invoice.paid? ? "invoice--paid" : "invoice--open"
  end
end

# View: <% presenter = InvoicePresenter.new(invoice) %>
#       <tr class="<%= presenter.css_class %>"><td><%= presenter.total %></td></tr>
```

## Failure modes

- applying the pattern because its name sounds sophisticated
- creating an abstraction around trivial code
- hiding dependencies or construction
- adding generic manager/processor classes
- changing behavior during an architectural refactor
- leaking framework or vendor details across the boundary

## Testing

Test the public contract first. Add focused collaborator tests where the pattern creates independently testable behavior. Keep integration tests for real framework or external boundaries.

## Review checklist

- Is the pattern justified by the problem shape?
- Is the interface smaller or clearer than the original coupling?
- Does it match repository conventions?
- Is construction explicit?
- Are failure cases covered?
- Would a simpler implementation be better?

## Related skills

- ruby-poro
- ruby-oop
- ruby-object-composition
- ruby-dependency-injection
- ruby-clean-code
- ruby-tdd-refactoring
