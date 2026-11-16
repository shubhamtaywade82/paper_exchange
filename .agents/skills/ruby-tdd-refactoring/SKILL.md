---
name: ruby-tdd-refactoring
description: Use when changing Ruby/Rails behavior, fixing bugs, adding coverage, refactoring, or working under a regression-risk constraint.
---

# Ruby TDD and Refactoring

## Purpose

Use tests as executable behavior contracts and keep structural changes small enough to verify continuously.

## Activate when

- behavior changes
- a bug is fixed
- a public method/API is modified
- code is refactored
- missing edge-case coverage is discovered
- a task explicitly requires TDD

## Repository inspection

Before writing tests:

- identify RSpec/Minitest/other stack
- inspect existing test organization
- inspect fixtures/factories/helpers
- inspect CI commands
- identify integration/system/request coverage
- reuse existing matchers and conventions

Do not introduce a second test framework without a reason.

## TDD loop

When practical:

```text
red
  -> smallest behavior
  -> green
  -> refactor
  -> regression suite
```

For an existing bug, a regression test should demonstrate the defect before the fix when feasible.

TDD is a development discipline, not a requirement to force a literal red/green sequence when working in a constrained production/debugging workflow.

## Test quality

A test should make the behavior easy to understand.

Prefer behavior-focused expectations.

Cover:

- normal behavior
- boundaries
- invalid input
- failure behavior
- important side effects
- regression conditions

Avoid coupling tests to incidental private implementation details.

## RSpec readability

When the repository uses RSpec, organize related examples with meaningful `describe`/`context` structure and descriptions that state behavior.

Use existing repository conventions for `subject`, helpers, shared examples, and factories.

## Refactoring

A refactor changes structure without intentionally changing observable behavior.

Sequence:

1. characterize current behavior
2. add missing coverage
3. make one structural change
4. run focused tests
5. inspect diff
6. repeat
7. run regression suite

## Algorithm evaluations

When an algorithm requirement gives complexity targets, tests must prove output while a separate check/review substantiates complexity and auxiliary space.

Include:

- empty input
- singleton
- duplicates
- already sorted/reverse-sorted
- boundary values
- impossible/no-result cases

## Failure modes

- tests that pass despite broken behavior
- over-mocking the system under test
- asserting implementation details
- one huge integration test for every behavior
- adding tests after a broad refactor with no characterization coverage
- changing tests simply to make a failing implementation pass

## Completion contract

A task is complete only when:

- intended behavior is implemented
- relevant tests pass
- regression coverage passes
- applicable static/lint/CI checks pass
- final diff has no accidental scope expansion
- any unrun verification is disclosed

## Reference example

Red-green-refactor as an executable loop: the test states the behavior first, then the implementation earns it.

```ruby
require "minitest/autorun"

# red: written first, fails against an empty implementation
class SlugTest < Minitest::Test
  def test_slugifies_title_cased_input
    assert_equal "four-great-ruby-books", Slug.call("Four Great Ruby Books!")
  end

  def test_collapses_repeated_separators
    assert_equal "a-b", Slug.call("a --  b")
  end
end

class Slug
  def self.call(title) = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
end

# green: run `ruby slug_test.rb` - both assertions pass, no app code was touched first.
```

## Agent review checklist

- [ ] repository test stack identified
- [ ] contract expressed by tests
- [ ] edge/failure paths considered
- [ ] regression case added when appropriate
- [ ] focused tests pass
- [ ] broader checks run where appropriate
- [ ] tests remain readable

## Verification

Run the smallest useful test first, then the affected suite, then broader regression checks as justified by the change.

## Source foundation

Grounded in the TDD and clean-test material of *Clean Ruby*, including the emphasis on behavior clarity and readable RSpec structure, and reinforced by the exercise-driven Ruby practice model of *The Ruby Workshop*.
