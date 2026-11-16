---
name: recovery-verification
description: Verify incident recovery through user-impact, dependency, workload, backlog, and data-integrity signals rather than a single process health check.
family: rails
---

# Recovery Verification

## Problem
A process can be healthy while users remain broken, queues remain backed up, or data integrity is still at risk.

## Use when
- closing incidents;
- validating rollback/roll-forward;
- verifying degraded-mode recovery.

## Do not use when
- defining the original SLO or RTO; use rails-reliability-engineering for that contract.

## Repository inspection
Inspect user-impact SLIs, dependency signals, queue/backlog metrics, error rates, data-integrity checks, health/readiness endpoints, and recovery objectives.

## Implementation procedure
1. Confirm the process/runtime is healthy. 2. Confirm the affected SLI recovered. 3. Confirm dependency behavior. 4. Confirm backlog or queue age is stable/recovering. 5. Check for hidden errors or data-integrity regressions. 6. Observe for the repository-defined recovery window. 7. Record evidence.

## Example

```ruby
# Post-recovery checks beyond "the process is up".
namespace :recovery do
  task verify: :environment do
    window = (ENV.fetch("INCIDENT_START").then { Time.iso8601(_1) })..Time.current
    checks = {
      "checkout success rate ≥ 99%" => Metrics.ratio("checkout.success", since: 15.minutes.ago) >= 0.99,
      "queue latency < 60s" => SolidQueue::ReadyExecution.minimum(:created_at).then { _1.nil? || _1 > 60.seconds.ago },
      "paid orders all have captured payments" =>
        Order.paid.where(updated_at: window).where.missing(:captured_payment).none?
    }
    checks.each { |name, ok| puts "#{ok ? 'PASS' : 'FAIL'} #{name}" }
    exit 1 unless checks.values.all?
  end
end
```

## Failure modes
- declaring recovery from /up alone;
- ignoring backlog;
- ignoring downstream failures;
- closing before monitoring period;
- failing to verify data integrity.

## Testing
Create deterministic failure scenarios and assert both recovery signals and explicit closure criteria.

## Review checklist
- [ ] user-impact signal; - [ ] dependency signal; - [ ] backlog signal; - [ ] integrity check; - [ ] monitoring window.

## Related skills
rails-incident-engineering, rails-observability, rails-reliability-engineering, rails-production-runtime