---
name: flaky-test-diagnosis
description: Diagnose nondeterministic test failures by reproducing the exact execution conditions.
family: testing
---

# Flaky Test Diagnosis

## Problem
A test that sometimes passes and sometimes fails provides weak evidence and can hide real regressions.

## Use when
A test fails intermittently or only under CI/parallel execution.

## Implementation procedure
1. Capture test name and random seed.
2. Capture Ruby/Rails/runtime and CI configuration.
3. Reproduce with identical parallelism/order.
4. Classify the failure: timing, state leak, order, transaction, external dependency, time zone, randomness, or environment.
5. Fix the source of nondeterminism.
6. Run repeated verification.
7. Keep a regression test for the discovered defect.

## Example

```bash
# 1. Reproduce with the failing seed and the same worker count as CI.
PARALLEL_WORKERS=4 bin/rails test test/models/order_test.rb --seed 48213

# 2. Bisect the order dependency: run the failing test after each candidate file.
bin/rails test test/models/shipping_test.rb test/models/order_test.rb --seed 48213

# 3. Fix the leak (e.g. reset class-level state in teardown) and prove it
#    with the original seed plus several fresh seeds.
for seed in 48213 1 2 3; do bin/rails test test/models --seed "$seed" || exit 1; done
```

## Failure modes
- adding retries as the fix
- increasing sleeps
- disabling parallel tests globally
- changing test order until the failure disappears

## Testing
Use repeated runs only as evidence of reproducibility; the fix must remove the underlying nondeterminism.

## Review checklist
- original conditions captured
- root cause classified
- actual isolation/timing issue fixed
- repeated verification performed


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture

## Do not use when

Do not use when the test failure is deterministic and reproducible under one stable execution configuration.
