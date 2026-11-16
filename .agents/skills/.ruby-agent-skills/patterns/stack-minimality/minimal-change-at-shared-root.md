---
name: minimal-change-at-shared-root
description: Minimal Change At Shared Root
family: stack-minimality
---
# Minimal Change At Shared Root

## Problem
A small diff is still wrong when it patches one symptom while siblings share the same broken owner.

## Use when
Bug fixes, validation gaps, authorization failures, and shared transformations.

## Do not use when
Callers intentionally have different contracts or a shared owner cannot enforce the invariant safely.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Search all callers and tests. Fix at the narrowest common owner when contracts are shared.

## Example

```ruby
# Symptom reported: the invoice PDF shows "$1,000.5" instead of "$1,000.50".
# Patching only InvoicePdf would leave the email, CSV, and dashboard wrong,
# because they all share Money#to_s.

# Before
class Money
  def to_s = "$#{format_amount}"

  private

  def format_amount = (cents / 100.0).to_s
end

# After: fix the shared owner once; every caller is corrected.
class Money
  def to_s = "$#{format("%.2f", cents / 100.0)}"
end
```

## Failure modes
Patch-per-caller and inconsistent duplicated guards.

## Testing
Add a regression test at the shared boundary and preserve representative caller coverage.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
ruby-debugging, ruby-tdd-refactoring, rails-architecture, react-architecture, stack-minimality
