---
name: ruby-debugging
description: Use when diagnosing Ruby/Rails exceptions, incorrect behavior, production failures, logging problems, unexpected state, or intermittent defects.
---

# Ruby Debugging

## Purpose

Turn an observed failure into a verified root cause and a regression-safe fix.

## Activate when

- an exception or failing test exists
- behavior is incorrect but the code appears plausible
- a production issue needs diagnosis
- logs do not explain an intermittent problem
- state becomes invalid somewhere upstream of the failure

## Repository inspection

Before debugging, inspect the repository context and then collect evidence:


Collect:

- exact error/message
- full relevant stack trace
- request/input
- relevant state
- Ruby/Rails/dependency versions
- recent changes
- reproducibility
- logs/metrics/traces available to the repository

Do not start by changing code.

## Debugging loop

```text
reproduce
  -> observe
  -> isolate
  -> inspect state
  -> form hypothesis
  -> test hypothesis
  -> patch root cause
  -> add regression coverage
  -> verify
```

A hypothesis should predict what evidence will change if it is correct.

## Stack traces

The exception location is where failure surfaced, not necessarily where invalid state was created.

Trace backwards through:

- arguments
- collaborators
- data loading
- normalization
- callbacks
- persistence
- external responses

## Logging

Good diagnostic logs identify:

- operation
- correlation/request identifier when available
- relevant domain identifier
- meaningful state transition

Do not log passwords, credentials, bearer tokens, secrets, or full sensitive payloads.

## Interactive debugging

Use the repository's supported debugger (`debug`, `byebug`, IDE tooling, etc.).

Inspect:

- receiver
- locals
- instance variables
- stack
- branch state
- database/external responses where relevant

## Intermittent failures

Look for:

- concurrency
- time
- ordering
- retries
- external dependency behavior
- shared mutable state
- database isolation/transactions

Avoid "fixes" that only add sleeps or retries without evidence.

## Fix discipline

Prefer the smallest root-cause fix that preserves unrelated behavior.

Then add a regression test that would have failed before the fix.

## Verification ladder

1. reproduce original failure
2. run focused regression test
3. run affected test group
4. run broader suite when appropriate
5. inspect final diff

If a check cannot be run, state that explicitly.

## Reference example

Reproduce first, then narrow: a minimal failing script with a filtered backtrace, before touching any application code.

```ruby
# repro.rb - the smallest script that exhibits the defect
def normalize(zip)
  zip.to_s.gsub(/\D/, "").rjust(5, "0")
end

expected = "00401"
actual = normalize(401)
if actual != expected
  puts "FAIL: expected #{expected.inspect}, got #{actual.inspect}"
  begin
    raise ArgumentError, "repro captured"
  rescue => e
    puts e.backtrace.first(2)
  end
else
  puts "PASS"
end
# next step: add a regression test that encodes this expectation
```

## Agent review checklist

- [ ] evidence captured
- [ ] hypothesis tested
- [ ] root cause distinguished from symptom
- [ ] regression test added/updated
- [ ] no sensitive data logged
- [ ] original reproduction now passes
- [ ] broader regression checked

## Verification

Use deterministic reproductions where possible. For production-only failures, capture the observed evidence and create the narrowest safe reproduction available.

## Source foundation

Based on the logging and debugging material in *The Ruby Workshop*. The evidence-first and regression-oriented approach is aligned with the testing/refactoring discipline of *Clean Ruby*.

## Book integration: interactive debugging

For a reproducible local failure, an interactive breakpoint can be useful at the point where state becomes suspicious. Inspect locals, receiver state, and the call path, then remove temporary breakpoints before the final patch.

Do not substitute a debugger for a hypothesis. The debugging loop remains:
reproduce -> inspect -> hypothesize -> test -> fix -> regression test -> verify.
