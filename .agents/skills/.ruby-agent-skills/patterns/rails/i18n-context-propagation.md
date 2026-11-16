---
name: i18n-context-propagation
description: Preserve or deliberately resolve locale across Rails background jobs, asynchronous work, and other execution boundaries.
family: rails
---

# I18n Context Propagation

## Problem

Request locale context does not automatically define the correct locale for work that executes later or on another execution unit.

## Use when

- adding localized jobs;
- changing locale-aware async work.

## Do not use when

- asynchronous work is locale-independent.

## Repository inspection

Inspect Active Job serializer/conventions, user/account locale preferences, enqueue timing, retries, and locale fallback behavior.

## Implementation procedure

1. Decide whether locale should be captured or re-read.
2. Store only durable locale identity when needed.
3. Validate supported locale at execution.
4. Scope I18n.with_locale during work.
5. Restore prior context.
6. Test retries and changed user preferences.

## Example

```ruby
# Capture the recipient's locale explicitly; the request locale is not the job's locale.
class OrderShippedJob < ApplicationJob
  def perform(order)
    locale = order.customer.locale.presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
    I18n.with_locale(locale) do
      OrderMailer.shipped(order).deliver_now
    end
  end
end

# Enqueued from an admin request in :en; the customer still gets :hi.
OrderShippedJob.perform_later(order)
```

## Failure modes

- request locale assumed in job;
- unsupported locale persisted;
- locale leakage between jobs;
- stale locale preference silently used.

## Testing

Test enqueue/perform locale behavior, invalid locale fallback, and consecutive jobs with different locales.

## Review checklist

- [ ] capture/re-read decision
- [ ] durable locale identity
- [ ] validation
- [ ] scoped context
- [ ] retry behavior
- [ ] tests

## Related skills

rails-i18n, rails-active-job, ruby-concurrency
