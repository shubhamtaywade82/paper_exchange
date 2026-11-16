---
name: active-support-callback-boundary
description: Define generic Active Support callback lifecycles without hiding application workflows in callback chains.
family: rails
---

# Active Support Callback Boundary

## Problem

Generic callbacks can make lifecycle behavior reusable, but they can also hide control flow and side effects.

## Use when

- defining custom lifecycle callbacks;
- reviewing before/around/after callback chains outside Active Record.

## Do not use when

- explicit methods are clearer;
- model-specific callbacks are already owned by Active Model/Active Record.

## Repository inspection

Inspect callback events, callers, side effects, abort semantics, ordering, and tests.

## Implementation procedure

1. Define the lifecycle event.
2. Define before/around/after semantics.
3. Make abort/failure behavior explicit.
4. Keep callbacks narrow.
5. Keep external effects out of generic callback infrastructure.
6. Test ordering and failure semantics.

## Example

```ruby
class ImportRun
  include ActiveSupport::Callbacks

  define_callbacks :import

  # A small, explicit lifecycle protocol: timing and cleanup around the run.
  set_callback :import, :before, -> { @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) }
  set_callback :import, :after, -> { Rails.logger.info("import took #{elapsed.round(2)}s") }

  def call(rows)
    run_callbacks(:import) { rows.each { |row| Importer.call(row) } }
  end

  private

  def elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
end
```

## Failure modes

- callback chain becomes business workflow;
- unclear abort behavior;
- nested around callbacks obscure control flow;
- callback invokes external service inside critical path.

## Testing

Test callback order, around nesting, abort behavior, exception propagation, and successful completion.

## Review checklist

- [ ] lifecycle event explicit
- [ ] ordering explicit
- [ ] failure/abort semantics explicit
- [ ] side effects bounded
- [ ] callback tests exist

## Related skills

- skills/rails-active-support/SKILL.md
- skills/rails-active-model/SKILL.md
- skills/rails-active-record/SKILL.md
