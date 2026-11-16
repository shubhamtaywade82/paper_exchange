---
name: ruby-domain-modeling
description: Use when business concepts, invariants, or policies are becoming implicit in procedural code and need explicit domain boundaries.
---

# Ruby Domain Modeling

## Purpose

Turn meaningful business concepts and invariants into explicit, testable Ruby objects while keeping the model proportional to the domain.

## Activate when

- business rules are duplicated across controllers or services
- primitives carry hidden domain meaning
- conditionals encode a stable business concept
- an invariant lacks a clear owner
- several workflows manipulate the same conceptual state

## Repository inspection

Inspect Active Record models, domain methods, value objects, services, policies, validations, database constraints, naming conventions, and existing domain modules.

Determine whether the repository favors rich models, domain POROs, service orchestration, or another established style.

## Decision rules

Give each invariant a clear owner.

Use a model/domain object for state and invariants it naturally owns, a value object for a meaningful immutable value, a policy/specification for reusable decisions, a service/command for application workflows, and a strategy for interchangeable algorithms.

Do not create a domain layer merely because the label sounds desirable.

## Implementation procedure

1. Identify the business concept and invariant.
2. Find every current implementation of the rule.
3. Choose the narrowest responsible owner.
4. Introduce the object or method with a stable API.
5. Redirect callers without changing behavior.
6. Remove duplicated rule implementations.
7. Add focused examples for the invariant.
8. Add regression coverage around affected workflows.

## Failure modes

- anemic objects plus giant services
- duplicate validations
- generic DomainService or Manager classes
- excessive indirection around simple rules
- moving persistence behavior away from Active Record without evidence
- modeling every noun as a class

## Reference example

A domain entity that refuses invalid states: invariants enforced at construction, intention revealed by named constructors.

```ruby
require "date"

# A domain entity that refuses invalid states: invariants enforced at
# construction, intention revealed by named constructors.
class Subscription
  attr_reader :plan, :renews_on

  def self.trial(days: 14) = new(:trial, Date.today + days)
  def self.paid(plan, renews_on) = new(plan, renews_on)

  def initialize(plan, renews_on)
    raise ArgumentError, "renewal date required" if renews_on.nil?
    @plan, @renews_on = plan, renews_on
    freeze
  end

  def active?(today = Date.today) = renews_on >= today
end

trial = Subscription.trial(days: 7)
raise "trial must be active" unless trial.active?
begin
  Subscription.paid(:pro, nil)
rescue ArgumentError => e
  puts "invariant held: #{e.message}"
end
puts "#{trial.plan} renews #{trial.renews_on}"
```

## Agent review checklist

- Is the business concept explicit?
- Is there one authoritative rule owner where practical?
- Does the abstraction reduce duplication?
- Is the API understandable without framework knowledge?
- Is the model proportional to actual complexity?

## Verification

Run focused domain tests and all workflows that consume the rule. Search for duplicated predicates or calculations after the change.

## Source foundation

This skill synthesizes the source material's emphasis on object responsibility, single responsibility, readable design, and refactoring. The domain-modeling taxonomy itself is repository guidance rather than a direct claim about a specific book chapter.
