---
name: deployment-gate
description: Convert release evidence into explicit pass/fail gates with bounded thresholds, ownership, and abort behavior.
family: rails
---

# Deployment Gate

## Problem
A release checklist without machine-verifiable consequences does not reliably prevent unsafe promotion.

## Use when
- adding CI/CD gates;
- reviewing approvals;
- introducing automated release aborts.

## Do not use when
- the repository already exposes an equivalent gate and no new contract is being designed.

## Repository inspection
Inspect CI checks, deployment stages, required statuses, health checks, approvals, override policy, and audit logging.

## Implementation procedure
1. Define the protected contract. 2. Select evidence. 3. Define pass/fail threshold/window. 4. Define timeout and abort behavior. 5. Assign owner/override authority. 6. Record the outcome.

## Example

```bash
# Promotion is blocked by checks that fail the pipeline, not by a checklist.
set -euo pipefail
bin/rails db:migrate:status | grep -q "^  down" && { echo "pending migrations"; exit 1; }
bundle exec bundler-audit check --update
curl --fail --max-time 5 "https://staging.example.test/up"
bin/rails runner 'exit(ReleaseGate.error_rate_last(minutes: 15) < 0.01 ? 0 : 1)'
kamal deploy --version "$GIT_SHA" --skip-push
```

## Failure modes
- gate with no observable signal;
- timeout with implicit success;
- overrides without audit;
- gate failure without recovery procedure.

## Testing
Test both pass and fail paths, including timeout and unauthorized override paths where supported.

## Review checklist
- [ ] evidence; - [ ] threshold; - [ ] owner; - [ ] abort; - [ ] audit; - [ ] test path.

## Related skills
rails-release-engineering, rails-reliability-engineering, rails-incident-engineering