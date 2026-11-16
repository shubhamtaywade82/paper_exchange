---
name: test-performance-budget
description: Optimize Rails test-suite performance using measured boot, database, factory, parallelization, and system-test costs.
family: testing
---

# Test Performance Budget

## Problem
Test suites grow until feedback becomes too slow to sustain development.

## Use when
A test suite or specific test group has a measured runtime problem.

## Implementation procedure
1. Establish total and component-level baseline.
2. Identify slow files/tests and boot/setup overhead.
3. Measure factory/fixture, DB, system-test, and parallel overhead.
4. Make the smallest targeted improvement.
5. Re-run the same workload.
6. Confirm assertions and isolation remain intact.

## Example

```bash
# Measure before optimizing: find where the suite spends its time.
bin/rails test --verbose 2>&1 | grep -E "^[A-Z].*= [0-9.]+ s" | sort -t= -k2 -nr | head -20

# Budget check in CI: fail when the unit suite exceeds its agreed ceiling.
start=$(date +%s)
bin/rails test test/models test/lib
elapsed=$(( $(date +%s) - start ))
if [ "$elapsed" -gt 120 ]; then echo "unit suite took ${elapsed}s (budget 120s)"; exit 1; fi
```

## Failure modes
- removing assertions to gain speed
- global parallelization without measuring overhead
- eager-loading every helper
- replacing real contract tests with mocks solely for speed

## Testing
Compare before/after runtime using the same environment/workload.

## Review checklist
- baseline exists
- bottleneck identified
- change targeted
- coverage preserved


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture

## Do not use when

Do not use when there is no measured test-runtime, boot-time, setup, or feedback-loop problem.
