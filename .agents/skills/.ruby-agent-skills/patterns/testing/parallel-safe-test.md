---
name: parallel-safe-test
description: Make tests independent of process/thread order, shared state, fixed resources, and implicit database transactions.
family: testing
---

# Parallel-Safe Test

## Problem
Parallel execution exposes hidden shared state and resource collisions.

## Use when
Enabling/tuning Rails parallel tests or fixing failures that appear only under parallel execution.

## Implementation procedure
1. Reproduce with the reported worker count/seed.
2. Identify shared state/resource.
3. Isolate database/process/port/filesystem/cache state.
4. Remove order dependency.
5. Verify transaction semantics for concurrent database work.
6. Re-run in parallel and serial modes.

## Example

```ruby
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  # Each worker gets its own port and scratch directory instead of sharing
  # a fixed port and a global array.
  parallelize_setup do |worker|
    ENV["TEST_SERVER_PORT"] = (4000 + worker).to_s
    FileUtils.mkdir_p(Rails.root.join("tmp", "test-worker-#{worker}"))
  end
end

class ExportTest < ActiveSupport::TestCase
  test "writes to a worker-local path" do
    path = Rails.root.join("tmp", "test-worker-#{ENV.fetch("TEST_ENV_NUMBER", "0")}", "export.csv")
    Export.new(orders(:one)).write(path)
    assert File.exist?(path)
  end
end
```

## Failure modes
- global variables/singletons leaking state
- fixed ports/temp paths
- shared external fake state
- test transaction blocking independent transactions
- reducing parallelism instead of fixing the race

## Testing
Run the focused case repeatedly under the parallel configuration and then the relevant suite.

## Review checklist
- failure reproduces under same seed/configuration
- shared state identified
- isolation fixed
- serial and parallel runs agree


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture

## Do not use when

Do not use when the test suite is not parallelized and the task has no shared-resource or order-independence concern.
