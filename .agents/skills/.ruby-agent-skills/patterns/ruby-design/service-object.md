---
name: service-object
description: Use when a named application workflow coordinates multiple collaborators, side effects, or external boundaries.
family: ruby-design
---

# Service Object

## Problem

A use case spans multiple responsibilities and does not have a natural home in one existing object.

## Use when

- an operation coordinates several domain objects
- side effects occur across boundaries
- a workflow deserves a stable entry point
- extracting the workflow improves testability

## Do not use when

- a method has one obvious owner
- the class only wraps one method call
- the repository already has a suitable command/application abstraction

## Repository inspection

Inspect existing service/application/command conventions, error/result conventions, dependency injection style, and test layout.

## Structure

~~~ruby
class CheckoutOrder
  def initialize(order, payment_gateway:, notifier:)
    @order = order
    @payment_gateway = payment_gateway
    @notifier = notifier
  end

  def call
    payment = @payment_gateway.charge(@order.total)
    @order.mark_paid!(payment)
    @notifier.order_paid(@order)
    @order
  end
end
~~~

The concrete failure/transaction behavior must follow the application contract.

## Implementation procedure

1. Name the use case after the domain action.
2. Define the input/output contract.
3. Identify collaborators and side effects.
4. Keep orchestration in the service; keep domain rules with their owners.
5. Define failure semantics.
6. Inject external boundaries where the repository supports it.
7. Add focused tests and integration coverage for important boundaries.

## Failure modes

- generic Manager/Processor classes
- moving all business logic into the service
- hidden global dependencies
- inconsistent return/error contracts
- network calls mixed with unrelated domain rules
- accidental transaction assumptions

## Testing

Test the workflow contract and collaborator interactions that matter. Use integration tests for critical external/database boundaries.

## Review checklist

- [ ] use case has one coherent purpose
- [ ] collaborators have clear contracts
- [ ] domain ownership remains intact
- [ ] failure semantics are explicit
- [ ] external dependencies are testable
- [ ] no unnecessary abstraction was introduced

## Related skills

- ruby-oop
- ruby-method-design
- ruby-gems-io-services
- ruby-clean-code
- ruby-tdd-refactoring
- rails-architecture

## Book integration: service convention

A Rails service should represent one actionable workflow. When the repository uses an ApplicationService base, a common convention is a single public call entry point with a domain-action name such as Post::Creator or Newsletter::Sender.

Keep helpers private. Define failure semantics explicitly rather than rescuing every exception by default. Broad rescue is only acceptable when the repository deliberately treats the entire operation as a safe boolean/result boundary and the lost exception information is handled elsewhere.
