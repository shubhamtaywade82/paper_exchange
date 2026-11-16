---
name: release-evidence
description: Preserve a machine-readable record of release identity, gate outcomes, exposure stages, recovery actions, and final state.
family: rails
---

# Release Evidence

## Problem
Without durable release evidence, operators cannot reconstruct what was tested, promoted, deployed, or recovered.

## Use when
- building release records;
- reviewing auditability;
- debugging deployment outcomes.

## Do not use when
- the existing release platform already captures equivalent immutable evidence.

## Repository inspection
Inspect deployment logs, artifact metadata, approvals, migration records, gate outputs, and incident links.

## Implementation procedure
1. Record source and artifact. 2. Record environment and timestamps. 3. Record gate outcomes. 4. Record exposure stage. 5. Record recovery actions. 6. Record final state. 7. Exclude secrets and sensitive payloads.

## Example

```yaml
# Recorded per release, stored with the deploy (no secrets).
release: 2026-09-27.3
source_sha: 4f1c2a9e0b7d3c6a58e1f2b3c4d5e6f708192a3b
image: registry.example.com/shop@sha256:9b2e…c41      # the digest CI tested and deploy ran
ci_run: https://github.com/example/shop/actions/runs/123456789
gates:
  tests: pass
  brakeman: pass (0 new warnings)
  migration_review: expand-only, approved by db-owners
exposure:
  - { at: "2026-09-27T10:02Z", percent: 10 }
  - { at: "2026-09-27T10:40Z", percent: 100 }
health_window: 60m, checkout success 99.7%, p95 410ms, queue lag < 5s
final_state: complete
```

## Failure modes
- mutable release records;
- missing artifact digest;
- missing failed-deployment evidence;
- sensitive values in logs.

## Testing
Verify that successful and failed release cases produce complete evidence records without secrets.

## Review checklist
- [ ] source; - [ ] artifact; - [ ] environment; - [ ] gates; - [ ] stage; - [ ] recovery; - [ ] final state; - [ ] secret-safe.

## Related skills
rails-release-engineering, rails-incident-engineering, rails-security-engineering