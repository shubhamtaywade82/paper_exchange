---
name: release-health-verification
description: Verify release success using user-impact, dependency, workload, readiness, and correctness signals over a defined observation window.
family: rails
---

# Release Health Verification

## Problem
A deployment can be technically healthy while user outcomes or background workloads remain degraded.

## Use when
- completing a production release;
- implementing automated release checks;
- investigating post-deploy regressions.

## Do not use when
- defining the SLO itself; use rails-reliability-engineering.

## Repository inspection
Inspect release health endpoints, SLIs/SLOs, dependency telemetry, queue/backlog signals, error reporting, and incident thresholds.

## Implementation procedure
1. Record baseline. 2. Deploy controlled exposure. 3. Verify process/readiness. 4. Compare user-impact metrics. 5. Verify dependency and backlog behavior. 6. Check correctness/data integrity signals. 7. Complete the observation window and record evidence.

## Example

```ruby
# Runs after deploy; a non-zero exit fails the pipeline and triggers rollback.
namespace :release do
  task verify_health: :environment do
    required_consecutive = 10 # 10 healthy minutes
    healthy_streak = 0
    30.times do # give up after 30 minutes
      success = Metrics.ratio("checkout.success", since: 5.minutes.ago, release: ENV.fetch("RELEASE"))
      p95 = Metrics.percentile("http.request_ms", 95, since: 5.minutes.ago)
      backlog = SolidQueue::ReadyExecution.count
      healthy = success >= 0.995 && p95 < 800 && backlog < 5_000
      puts "success=#{success} p95=#{p95} backlog=#{backlog} healthy=#{healthy}"

      abort "release #{ENV['RELEASE']} breached the rollback threshold" if success < 0.98
      healthy_streak = healthy ? healthy_streak + 1 : 0
      if healthy_streak >= required_consecutive
        puts "release verified"
        break
      end

      sleep 60
    end
    abort "release did not reach #{required_consecutive} healthy minutes" if healthy_streak < required_consecutive
  end
end
```

## Failure modes
- using /up alone;
- no baseline;
- too-short observation window;
- ignoring worker/backlog behavior;
- ignoring correctness.

## Testing
Test release health gates with synthetic regressions and deterministic pass/fail windows.

## Review checklist
- [ ] baseline; - [ ] process/readiness; - [ ] user SLI; - [ ] dependency; - [ ] queue; - [ ] correctness; - [ ] window.

## Related skills
rails-release-engineering, rails-observability, rails-reliability-engineering, rails-incident-engineering