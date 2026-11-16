---
name: action-mailbox-routing-contract
description: Define deterministic Action Mailbox recipient routing, precedence, and unmatched-email behavior.
family: rails
---

# Action Mailbox Routing Contract

## Problem

Mailbox routing is easy to make ambiguous when broad patterns, aliases, and catch-all rules overlap.

## Use when

- adding a mailbox route;
- changing recipient aliases;
- introducing catch-all/backstop routing;
- reviewing misrouted inbound mail.

## Do not use when

- routing is not changing and the task only changes mailbox internals.

## Repository inspection

Inspect ApplicationMailbox, route order, address normalization, existing mailbox classes, tenant/alias lookup, and tests for overlapping recipients.

## Implementation procedure

1. Enumerate supported recipient forms.
2. Place specific routes before general routes.
3. Define normalization rules.
4. Define one explicit unmatched/backstop policy.
5. Keep routing separate from resource authorization.
6. Test positive, collision, and unmatched cases.
7. Add route-level diagnostics where the repository already has tracing.

## Example

```ruby
class ApplicationMailbox < ActionMailbox::Base
  # Specific routes first, catch-all last; the first match wins.
  routing(/\Areply\+[a-z0-9]+@/i => :replies)
  routing(/\Ainvoices@/i => :invoices)
  routing(/\Asupport@/i => :support)
  routing(all: :unrouted)
end

class UnroutedMailbox < ApplicationMailbox
  def process
    bounce_with(SupportMailer.unroutable(inbound_email))
  end
end
```

## Failure modes

- broad route shadows a specific route;
- case/normalization mismatch;
- tenant authorization inferred from recipient pattern;
- silent unmatched-message loss;
- alias change breaks old/new compatibility.

## Testing

Test route precedence, aliases, normalization, unmatched recipients, and cross-tenant recipient attempts.

## Review checklist

- [ ] route order explicit
- [ ] normalization explicit
- [ ] catch-all behavior intentional
- [ ] routing distinct from authorization
- [ ] collisions tested
- [ ] unmatched behavior tested

## Related skills

- skills/rails-action-mailbox/SKILL.md
- skills/rails-routing/SKILL.md
- skills/rails-security-engineering/SKILL.md
