---
name: progressive-delivery
description: Expose a release incrementally and gate expansion on user-impact and resource evidence.
family: rails
---

# Progressive Delivery

## Problem
All-at-once production exposure increases blast radius when a release is defective.

## Use when
- implementing canary/staged releases;
- using traffic or feature-flag based exposure;
- reviewing rollout safety.

## Do not use when
- the platform cannot provide controlled exposure or no meaningful decision gate exists.

## Repository inspection
Inspect deployment topology, traffic routing, feature flags, health/SLI dashboards, abort controls, and exposure ownership.

## Implementation procedure
1. Choose the smallest useful exposure. 2. Define observation window. 3. Select user-impact/resource gates. 4. Expand only after evidence passes. 5. Abort or roll back on defined regression. 6. Record each stage.

## Example

```ruby
# Exposure widens only after each stage's gate holds.
class NewCheckoutRollout
  STAGES = [
    { percent: 1,   hold: 30.minutes },
    { percent: 10,  hold: 2.hours },
    { percent: 50,  hold: 24.hours },
    { percent: 100, hold: nil }
  ].freeze

  def advance!(to_percent)
    abort_rollout!("gate failed") unless gate_healthy?
    Flipper.enable_percentage_of_actors(:new_checkout, to_percent)
  end

  def abort_rollout!(reason)
    Flipper.disable(:new_checkout) # instant, no deploy
    Rails.logger.warn(event: "rollout.aborted", flag: "new_checkout", reason:)
  end

  private

  # Compare the exposed cohort to control, not to yesterday.
  def gate_healthy?
    Metrics.ratio("checkout.success", flag: "new_checkout", variant: "on") >=
      Metrics.ratio("checkout.success", flag: "new_checkout", variant: "off") - 0.005
  end
end
```

## Failure modes
- false canary with no reduced exposure;
- process-health-only gate;
- exposure too small to produce signal;
- no abort path;
- human expansion with no evidence.

## Testing
Exercise staged rollout logic with deterministic regression signals and abort/expand cases.

## Review checklist
- [ ] reduced exposure; - [ ] useful signal; - [ ] window; - [ ] abort; - [ ] stage record.

## Related skills
rails-release-engineering, rails-reliability-engineering, rails-incident-engineering, rails-production-runtime