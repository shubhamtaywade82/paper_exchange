---
name: alert-actionability
description: Design alerts around actionable user-impact or system-risk signals with bounded context, ownership, and recovery conditions.
family: rails
---

# Alert Actionability

## Problem
Alerts that lack an operator action increase noise without shortening detection or mitigation time.

## Use when
- adding or reviewing paging/alert rules;
- reducing alert fatigue;
- converting raw telemetry into operational signals.

## Do not use when
- selecting ordinary application log messages;
- no operator action is associated with the signal.

## Repository inspection
Inspect SLOs, existing alerts, alert routing, dashboards, severity definitions, suppression/deduplication, and ownership.

## Implementation procedure
1. Identify the contract protected. 2. Define the signal/window. 3. Define severity. 4. Attach diagnostic links/context. 5. Define immediate operator action. 6. Define recovery/resolution. 7. Test firing, deduplication, and resolution.

## Example

```yaml
# Each alert names an owner, a runbook action, and the user-facing signal it
# protects; it pages only when an operator can act.
- alert: CheckoutErrorBudgetBurn
  expr: |
    sum(rate(http_requests_total{route="checkout", status=~"5.."}[5m]))
      / sum(rate(http_requests_total{route="checkout"}[5m])) > 0.02
  for: 10m
  labels:
    severity: page
    owner: payments-team
  annotations:
    summary: "Checkout 5xx above 2% for 10 minutes"
    runbook: "https://runbooks.example.test/checkout-errors"
    first_action: "Check the payment provider status page and the checkout deploy log; roll back the last deploy if it correlates."
```

## Failure modes
- paging on every exception;
- alerting on non-actionable metrics;
- missing ownership;
- alerts with no recovery condition;
- sensitive payloads embedded in notifications.

## Testing
Use deterministic metric or event fixtures to test fire, suppression/deduplication, and recovery behavior.

## Review checklist
- [ ] actionable; - [ ] user/system contract named; - [ ] owner; - [ ] diagnostic context; - [ ] recovery condition; - [ ] bounded sensitivity.

## Related skills
rails-incident-engineering, rails-observability, rails-reliability-engineering