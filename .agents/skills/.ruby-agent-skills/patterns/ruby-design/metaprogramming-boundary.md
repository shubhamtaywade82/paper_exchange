---
name: metaprogramming-boundary
description: Use when dynamic Ruby behavior is required and its scope must remain explicit, discoverable, testable, and safe.
family: ruby-design
---

# Metaprogramming Boundary

## Problem

Dynamic Ruby can remove repetitive code, but unrestricted runtime behavior makes APIs harder to search, reason about, debug, and secure.

## Use when

- a framework-style DSL generates methods
- a stable set of names is generated from trusted configuration
- reflection is required by an existing protocol

## Do not use when

- explicit methods are equally clear
- dynamic behavior is only removing a few lines
- user input controls method names
- a wrapper, strategy, or adapter expresses the concept directly

## Repository inspection

Identify the dynamic entry point, generated names, caller set, visibility, test coverage, dependency hooks, and security/trust boundary.

## Implementation procedure

1. define the allowed dynamic surface
2. validate generated names from trusted input
3. generate only the required methods
4. keep generated behavior deterministic
5. implement reflection helpers such as respond_to_missing? when needed
6. document the reason for dynamic behavior
7. test generated and unsupported cases
8. provide an explicit alternative when practical

## Example

```ruby
# Dynamic method generation from a closed, reviewed list: searchable by name,
# no user input reaches define_method or public_send.
class FeatureFlags
  FLAGS = %i[new_checkout bulk_export beta_dashboard].freeze

  def initialize(enabled)
    @enabled = enabled.to_set
  end

  FLAGS.each do |flag|
    define_method(:"#{flag}?") { @enabled.include?(flag) }
  end

  def enabled?(name)
    flag = FLAGS.find { |candidate| candidate.to_s == name.to_s }
    raise ArgumentError, "unknown flag: #{name}" unless flag

    public_send(:"#{flag}?")
  end
end
```

## Failure modes

- unrestricted send or method_missing
- monkey patches with no compatibility reason
- generated APIs that cannot be discovered
- dynamic dispatch bypassing authorization
- version upgrades silently breaking generated behavior

## Testing

Test generation, reflection, visibility, unsupported names, and dependency-upgrade-sensitive behavior.

## Review checklist

- [ ] ordinary Ruby was considered first
- [ ] dynamic surface is bounded
- [ ] generated names are trusted/validated
- [ ] reflection behavior is coherent
- [ ] security boundaries remain explicit
- [ ] tests cover the dynamic path

## Related skills

- ruby-metaprogramming
- ruby-api-design
- ruby-oop
- ruby-debugging
