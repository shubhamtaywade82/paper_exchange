---
name: parallel-database-test
description: Configure concurrent database tests without accidental transaction blocking or connection exhaustion.
family: testing
---

# Parallel Database Test

## Problem
Concurrent test transactions can conflict with Rails' implicit transactional test wrapper and database capacity.

## Use when
Testing parallel transactions, locks, race conditions, or thread-based database behavior.

## Implementation procedure
1. Determine whether independent DB transactions are required.
2. Disable transactional tests only for the affected test case when necessary.
3. Clean up data explicitly.
4. Ensure enough DB connections for concurrent workers.
5. Use deterministic coordination primitives instead of sleeps.
6. Run the test under both the intended concurrency configuration and normal serial mode.

## Example

```ruby
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
end

# Only this case needs committed rows visible to another connection, so only
# it opts out of the transactional wrapper and cleans up after itself.
class InventoryLockingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown { InventoryItem.delete_all }

  test "concurrent reservations never oversell" do
    item = InventoryItem.create!(sku: "A1", quantity: 1)
    threads = 2.times.map { Thread.new { InventoryReservation.call(item.id) rescue nil } }
    threads.each(&:join)
    assert_equal 0, item.reload.quantity
  end
end
```

## Failure modes
- disabling transactional tests globally
- deadlocking on the outer test transaction
- leaking created data
- exceeding test DB connection capacity

## Testing
Exercise conflicting transactions and verify final database invariants.

## Review checklist
- transactional wrapper understood
- cleanup explicit when disabled
- connection demand understood
- synchronization deterministic


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture

## Do not use when

Do not use when the test does not require independent concurrent database transactions or database concurrency behavior.
