---
name: operational-task-boundary
description: Operational Task Boundary
family: rails
---
# Operational Task Boundary

## Problem
Operational code becomes unsafe when command orchestration and domain behavior are mixed without an explicit boundary.

## Use when
Adding or changing a maintenance command, Rake task, or runner workflow.

## Do not use when
A normal request path or reusable domain service with no operational interface.

## Repository inspection
Inspect lib/tasks, Rakefile, runner scripts, services, jobs, and runbooks.

## Implementation procedure
Keep the task as orchestration and delegate reusable business behavior to tested Ruby objects.

## Example

```ruby
# The task parses input and reports; the domain object owns the behavior and is tested directly.
namespace :subscriptions do
  desc "Renew subscriptions due on DATE (default today)"
  task renew_due: :environment do
    date = ENV["DATE"] ? Date.iso8601(ENV["DATE"]) : Date.current
    result = Subscriptions::RenewDue.new(date:).call
    puts "renewed=#{result.renewed} skipped=#{result.skipped} failed=#{result.failed.size}"
    exit 1 if result.failed.any?
  end
end

module Subscriptions
  class RenewDue
    Result = Struct.new(:renewed, :skipped, :failed)

    def initialize(date:) = @date = date

    def call
      result = Result.new(0, 0, [])
      Subscription.due_on(@date).find_each do |subscription|
        if subscription.renewed_for?(@date)
          result.skipped += 1 # a rerun after partial success skips completed work
        else
          subscription.renew!(@date)
          result.renewed += 1
        end
      rescue Subscription::RenewalError => e
        result.failed << [subscription.id, e.message]
      end
      result
    end
  end
end
```

## Failure modes
Unmaintainable task logic, duplicated business rules, and untestable operations.

## Testing
Test the task boundary and the delegated object separately.

## Review checklist
[ ] ownership [ ] thin orchestration [ ] reusable domain logic [ ] testable

## Related skills
rails-operational-tasks-maintenance, ruby-service-objects