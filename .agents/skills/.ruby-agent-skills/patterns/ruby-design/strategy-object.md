---
name: strategy-object
description: Use when one stable workflow needs interchangeable algorithms or policies selected by explicit runtime context.
family: ruby-design
---

# Strategy Object

## Problem

A method contains multiple algorithm branches that share a contract but vary independently.

## Use when

- algorithms have a common interface
- the selected behavior changes by configuration/domain state
- each variant can be tested independently

## Do not use when

- there are only two trivial branches
- strategies will never vary independently
- the abstraction merely moves an if into another file

## Repository inspection

Inspect existing polymorphism, configuration, dependency injection, and naming conventions.

## Structure

~~~ruby
class PriceCalculator
  def initialize(strategy)
    @strategy = strategy
  end

  def call(order)
    @strategy.calculate(order)
  end
end

class RegularPricing
  def calculate(order)
    order.subtotal
  end
end

class DiscountPricing
  def calculate(order)
    order.subtotal * 0.9
  end
end
~~~

The strategy contract should be defined by the real domain, not by this example.

## Implementation procedure

1. Identify the stable operation.
2. Identify the variable algorithm/policy.
3. Define the smallest shared interface.
4. Move each variant behind that interface.
5. Make selection explicit.
6. Test each strategy and the selection boundary.

## Failure modes

- strategy classes with trivial one-line branches
- implicit global strategy selection
- inconsistent method contracts
- strategies sharing hidden mutable state
- using inheritance when composition is sufficient

## Testing

Test each strategy against its contract and test the selector separately when selection logic exists.

## Review checklist

- [ ] common contract is real
- [ ] variants are independently meaningful
- [ ] selection is explicit
- [ ] strategy state is controlled
- [ ] tests cover each variant

## Related skills

- ruby-oop
- ruby-modules-mixins
- ruby-method-design
- ruby-clean-code
