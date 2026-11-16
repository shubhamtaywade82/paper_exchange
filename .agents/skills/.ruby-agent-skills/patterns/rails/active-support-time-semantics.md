---
name: active-support-time-semantics
description: Keep Rails time, date, timezone, and elapsed-duration behavior explicit and correct across DST and concurrency boundaries.
family: rails
---

# Active Support Time Semantics

## Problem

Application bugs often come from mixing local wall-clock time, UTC persistence, dates, and elapsed-duration measurement.

## Use when

- changing Time.zone behavior;
- using Active Support time/date helpers;
- debugging DST/off-by-one-day issues;
- measuring elapsed durations.

## Do not use when

- the task is purely date formatting with no timezone or timing semantics.

## Repository inspection

Inspect application timezone configuration, persistence conventions, locale/timezone context, scheduled jobs, and time-related tests.

## Implementation procedure

1. Classify the value as date, timestamp, local wall-clock, or elapsed duration.
2. Use the repository's UTC/local persistence convention.
3. Use Time.zone for application-local calendar semantics.
4. Use monotonic timing for elapsed-duration measurements.
5. Test DST and boundary transitions when relevant.
6. Keep timezone separate from identity/authorization.

## Example

```ruby
# Persist UTC, present in the user's zone, measure durations monotonically.
Time.use_zone(current_user.time_zone) do
  due_on = Time.zone.today + 3                  # a calendar date in the user's zone
  starts_at = Time.zone.parse("2026-03-01 09:00") # zone-aware wall-clock time
  Appointment.create!(starts_at: starts_at, due_on: due_on) # stored as UTC
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
SyncJob.perform_now
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started # immune to clock changes

# Avoid: Time.now / Date.today (system zone), and Time.current - started for timing.
```

## Failure modes

- system timezone leaking into application logic;
- adding seconds to timestamps when calendar semantics were required;
- wall-clock duration measurement;
- DST boundary bugs;
- timezone selected from unauthorized/untrusted context.

## Testing

Test UTC/local conversion, date boundaries, DST-sensitive operations, and duration measurement semantics.

## Review checklist

- [ ] value type identified
- [ ] timezone owner explicit
- [ ] persistence convention explicit
- [ ] DST considered
- [ ] elapsed timing uses monotonic source where needed

## Related skills

- skills/rails-active-support/SKILL.md
- skills/rails-i18n/SKILL.md
- skills/ruby-concurrency/SKILL.md
- skills/rails-test-engineering/SKILL.md
