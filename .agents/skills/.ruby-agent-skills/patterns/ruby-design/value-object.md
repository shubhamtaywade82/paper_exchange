---
name: value-object
description: Use when a primitive value has meaningful domain validation, normalization, comparison, formatting, or behavior.
family: ruby-design
---

# Value Object

## Problem

A primitive such as a String, Integer, or Hash has accumulated domain meaning and callers repeatedly implement the same rules.

## Use when

- validation belongs with the value
- normalization must be consistent
- comparison/formatting has domain semantics
- the value has a stable concept but no independent lifecycle

## Do not use when

- a plain primitive is already clear
- the wrapper has no behavior
- the class exists only to increase abstraction count

## Repository inspection

Inspect existing value objects, serializers, factories, validations, and naming conventions before introducing one.

## Structure

~~~ruby
class EmailAddress
  attr_reader :value

  def initialize(value)
    @value = normalize(value)
    validate!
  end

  def ==(other)
    other.is_a?(EmailAddress) && value == other.value
  end

  private

  def normalize(value)
    value.to_s.strip.downcase
  end

  def validate!
    raise ArgumentError, "invalid email" unless value.include?("@")
  end
end
~~~

The example is illustrative. Do not copy its validation policy into a real application without evidence.

## Implementation procedure

1. Identify the repeated primitive-level rule.
2. Confirm the value has a coherent domain concept.
3. Define construction and invalid-state behavior.
4. Keep the public API small.
5. Preserve serialization boundaries explicitly.
6. Replace callers incrementally.
7. Add equality/formatting only when required by the domain.

## Failure modes

- primitive wrapper with no behavior
- validation duplicated outside the object
- surprising coercion
- hidden normalization
- persistence/serialization coupled to the value object unnecessarily

## Testing

Test valid construction, invalid construction, normalization, equality, serialization boundaries, and edge cases that affect the domain contract.

## Review checklist

- [ ] domain meaning is real
- [ ] invalid states are controlled
- [ ] API is minimal
- [ ] normalization is explicit
- [ ] persistence boundary is clear
- [ ] tests describe behavior

## Related skills

- ruby-data-types
- ruby-oop
- ruby-method-design
- ruby-clean-code
- ruby-tdd-refactoring
