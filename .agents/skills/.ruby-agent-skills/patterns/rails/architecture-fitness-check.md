---
name: architecture-fitness-check
description: Architecture Fitness Check Contract
family: architecture
---
# Architecture Fitness Check Contract

## Problem
Architecture rules decay when they exist only in documentation.

## Use when
A boundary or dependency rule can be mechanically detected.

## Do not use when
The rule depends on nuanced runtime/business judgment that cannot be reduced safely.

## Repository inspection
Inspect static structure, namespaces, dependencies, routes, public APIs, schemas, and existing validators.

## Implementation procedure
Encode stable structural rules as tests/checks while keeping higher-order review human/agent-driven.

## Example

```ruby
# An executable architecture rule: code outside Billing may call only the
# public Billing entry point, never its internals.
class BillingBoundaryTest < ActiveSupport::TestCase
  INTERNAL = /\bBilling::(Charge|Ledger|InvoiceNumbering)\b/

  test "no code outside app/billing references Billing internals" do
    offenders = Dir[Rails.root.join("app/**/*.rb")].reject { |path| path.include?("/app/billing/") }.select do |path|
      File.read(path).match?(INTERNAL)
    end

    assert_empty offenders.map { |path| path.delete_prefix(Rails.root.to_s + "/") }
  end
end
```

## Failure modes
Brittle checker, false positives, gaming, architecture reduced to folder names.

## Testing
Run the check against known-valid and known-invalid fixtures when possible.

## Review checklist
[ ] rule stable [ ] executable [ ] false-positive path [ ] not gameable

## Related skills
rails-staff-principal-architecture, rails-test-engineering