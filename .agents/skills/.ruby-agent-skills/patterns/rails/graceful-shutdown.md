---
name: graceful-shutdown
description: Make Rails web and job processes stop safely within the platform termination budget.
family: rails
---

# Graceful Shutdown

## Problem
Abrupt process termination can drop requests, interrupt jobs, or leak resources.

## Use when
Changing TERM/QUIT handling, container shutdown, process-manager configuration, worker lifecycle, or restart behavior.

## Implementation procedure
1. Identify termination signal sequence.
2. Identify the hard kill deadline.
3. Stop accepting new work.
4. Allow safe in-flight work to finish.
5. Release resources.
6. Exit before the hard deadline.
7. Test graceful termination and forced termination recovery.

## Example

```ruby
# config/puma.rb
workers Integer(ENV.fetch("WEB_CONCURRENCY", 2))
threads 5, 5
# Finish in-flight requests before the platform's SIGKILL (terminationGracePeriodSeconds: 30).
worker_shutdown_timeout 25

# Job side: long jobs checkpoint so an interrupted run resumes instead of restarting.
class ExportRowsJob < ApplicationJob
  def perform(export_id)
    export = Export.find(export_id)
    export.rows_after(export.cursor).find_each do |row|
      export.append!(row)
      export.update!(cursor: row.id) # progress survives SIGTERM + retry
    end
    export.complete!
  end
end
```

## Failure modes
- shutdown timeout exceeds orchestrator kill timeout
- PID 1 swallows signals
- job workers exit before safe handoff
- long-running work cannot be interrupted/replayed safely

## Review checklist
- signal flow understood
- deadline compatible
- in-flight work semantics understood
- resources released
- recovery path exists


## Repository inspection

Inspect runtime/version, repository conventions, the owning boundary, neighboring implementations, and applicable tests before applying the pattern.


## Related skills

- rails-test-engineering
- ruby-tdd-refactoring
- rails-architecture
## Do not use when

Do not use when the change has no process lifecycle, termination, restart, or resource-release concern.

## Testing

Test signal forwarding, graceful completion, timeout behavior, and recovery after forced termination.
