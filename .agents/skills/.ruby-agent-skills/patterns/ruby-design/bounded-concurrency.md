---
name: bounded-concurrency
description: A bounded worker/queue pattern for concurrent I/O or producer-consumer workloads.
family: ruby-design
---

# Bounded Concurrency

## Problem

Concurrent work can overwhelm memory, database connections, external services, or CPU when every input creates an independent worker.

## Use when

Use when independent work benefits from concurrency and the repository has a measurable capacity boundary.

## Do not use when

Do not use for CPU-bound Ruby work that needs true parallelism, trivial workloads, or cases where existing framework/job infrastructure already owns concurrency.

## Repository inspection

Inspect runtime compatibility, existing executors/queues, database and HTTP pool limits, external rate limits, lifecycle, and shutdown conventions.

## Implementation procedure

1. Identify the capacity constraint.
2. Choose a bounded worker count below the resource ceiling.
3. Use a thread-safe queue or existing executor.
4. Define startup, failure propagation, completion, and shutdown.
5. Keep shared mutable state synchronized or owned by one worker.
6. Avoid I/O while holding application locks.
7. Add deterministic completion/failure tests.
8. Measure throughput/latency against a sequential baseline.

## Example

```ruby
# A fixed pool of workers drains a bounded queue: concurrency is capped at
# POOL_SIZE no matter how many inputs arrive.
POOL_SIZE = 4

def fetch_all(urls, client:)
  queue = Queue.new
  urls.each { |url| queue << url }
  POOL_SIZE.times { queue << :done }

  results = Queue.new
  workers = Array.new(POOL_SIZE) do
    Thread.new do
      while (url = queue.pop) != :done
        results << [url, client.get(url)]
      end
    end
  end
  workers.each(&:join)

  Array.new(results.size) { results.pop }.to_h
end
```

## Failure modes

- one thread per item
- unbounded queues
- workers exceeding database/API capacity
- detached workers
- swallowed worker exceptions
- sleeps used for synchronization
- in-process mutex used for cross-process coordination

## Testing

Test normal completion, worker failure, shutdown, queue draining, and resource bounds. Use controlled synchronization instead of arbitrary sleeps.

## Review checklist

- Is concurrency justified?
- Is worker count bounded?
- Is the capacity boundary explicit?
- Are failures observable?
- Is lifecycle owned?
- Does the pattern respect Rails/process boundaries?
- Would existing framework infrastructure be simpler?

## Related skills

- ruby-concurrency
- ruby-dependency-injection
- ruby-debugging
- ruby-tdd-refactoring
- rails-release-engineering
