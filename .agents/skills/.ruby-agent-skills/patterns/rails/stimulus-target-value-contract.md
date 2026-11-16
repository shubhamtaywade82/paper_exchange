---
name: stimulus-target-value-contract
description: Use explicit Stimulus targets and values as a stable controller/view interface.
family: rails
---
# Stimulus Target and Value Contract

## Problem
Controller code relies on scattered selectors and implicit DOM formats.

## Structure
Define named targets and values and validate assumptions at the controller boundary.

## Example

```js
// app/javascript/controllers/quantity_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "total"]
  static values = { unitPriceCents: Number, max: { type: Number, default: 10 } }

  connect() {
    if (!Number.isInteger(this.unitPriceCentsValue)) {
      throw new Error("quantity: data-quantity-unit-price-cents-value must be an integer")
    }
    this.update()
  }

  update() {
    const quantity = Math.min(Math.max(parseInt(this.inputTarget.value, 10) || 1, 1), this.maxValue)
    this.inputTarget.value = quantity
    this.totalTarget.textContent = (quantity * this.unitPriceCentsValue / 100).toFixed(2)
  }
}

// Markup:
// <div data-controller="quantity" data-quantity-unit-price-cents-value="<%= @product.price_cents %>">
//   <input type="number" data-quantity-target="input" data-action="input->quantity#update">
//   ₹<span data-quantity-target="total"></span>
// </div>
// The server recomputes the price; the displayed total is presentation only.
```

## Failure modes
Renamed DOM nodes, missing targets, and implicit string formats.

## Testing
Cover required/missing targets and representative value changes.

## Do not use when
The DOM contract is trivial and no controller boundary exists.

## Repository inspection
Inspect HTML naming conventions, controller values, targets, type coercion, and tests.

## Implementation procedure
Define target/value names, types, defaults, required state, and failure behavior.

## Failure modes
Missing targets, implicit string parsing, selector drift, and undocumented DOM changes.

## Testing
Cover required targets, values, and representative mutations.

## Review checklist
View markup and controller code share an explicit contract.

## Related skills
rails-hotwire, rails-action-view, rails-test-engineering

## Use when

Use this pattern when the named behavior is an intentional part of the browser interaction contract.
