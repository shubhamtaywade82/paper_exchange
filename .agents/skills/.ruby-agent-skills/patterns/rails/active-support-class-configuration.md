---
name: active-support-class-configuration
description: Use class_attribute for deliberately inherited Rails configuration without creating hidden mutable global state.
family: rails
---

# Active Support Class Configuration

## Problem

Framework classes often need inherited configuration with subclass overrides, but mutable class state can leak across hierarchy levels.

## Use when

- adding class_attribute;
- designing subclass-overridable configuration;
- reviewing inheritable class settings.

## Do not use when

- configuration is request-scoped, tenant-scoped, or instance-specific.

## Repository inspection

Inspect class hierarchy, defaults, inheritance expectations, mutation patterns, and tests.

## Implementation procedure

1. Define the owning class.
2. Define default value.
3. Define override semantics.
4. Prefer immutable values or copy-on-write updates.
5. Restrict instance access unless required.
6. Test parent/subclass isolation.

## Example

```ruby
class BaseExporter
  # Inherited, overridable configuration. Frozen defaults and non-mutating
  # overrides keep subclasses from changing the parent's value.
  class_attribute :columns, instance_writer: false, default: %w[id created_at].freeze
end

class OrderExporter < BaseExporter
  self.columns = columns + %w[total status] # new array, parent untouched
end

BaseExporter.columns  # => ["id", "created_at"]
OrderExporter.columns # => ["id", "created_at", "total", "status"]
```

## Failure modes

- shared mutable hash/array;
- subclass mutation changes parent behavior;
- request state stored in class_attribute;
- instance writer unintentionally exposes global configuration.

## Testing

Test inheritance, subclass override, parent isolation, default behavior, and concurrent access when mutable state remains.

## Review checklist

- [ ] inheritance intentional
- [ ] default explicit
- [ ] mutability controlled
- [ ] instance access justified
- [ ] parent/subclass isolation tested

## Related skills

- skills/rails-active-support/SKILL.md
- skills/ruby-concurrency/SKILL.md
- skills/rails-production-runtime/SKILL.md
