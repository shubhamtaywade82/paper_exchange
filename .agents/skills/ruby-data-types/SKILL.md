---
name: ruby-data-types
description: Use when choosing, parsing, validating, or reviewing Ruby values such as strings, numbers, symbols, ranges, nil, arrays, hashes, or domain value representations.
---

# Ruby Data Types

## Purpose

Choose data representations that make contracts obvious and keep invalid states difficult to create.

## Activate when

- an API or method needs a new value representation
- input is parsed or normalized
- hashes are becoming structured domain data
- nilability or empty values matter
- a primitive value is acquiring behavior or validation
- serialization/deserialization crosses a boundary

## Repository inspection

Inspect:

- supported Ruby version
- schema/JSON/API payload shape
- existing value objects and conventions
- serialization libraries
- nil/empty conventions
- tests that describe boundary behavior

Do not impose a new representation when an established one already exists.

## Decision rules

### Primitive versus object

Use a primitive when the value has simple semantics.

Introduce a value object when the value has meaningful:

- validation
- normalization
- comparison
- formatting
- domain behavior
- identity beyond its raw representation

Do not create classes merely to wrap a single primitive.

### Strings

At input boundaries distinguish:

- missing
- empty
- whitespace-only
- normalized text
- invalid encoding/format

Do not silently `strip`, downcase, transliterate, or coerce unless the contract requires it.

### Symbols

Use symbols for stable symbolic identifiers when that matches project conventions. Do not convert arbitrary external user input directly into symbols without considering the runtime/version and lifecycle of those values.

### Numbers

Preserve numeric semantics through calculations. At external boundaries, distinguish numeric text from numeric values and validate conversion failures explicitly.

### Nil

Treat `nil` as meaningful state. Do not use empty strings, empty collections, or sentinel values as accidental substitutes.

### Hashes

Before creating a structured hash, define:

- required keys
- optional keys
- value shapes
- ownership/mutation
- serialization expectations

When the hash gains substantial behavior, consider a domain object.

### Ranges

Use ranges when they express a meaningful interval or sequence. Verify inclusive/exclusive semantics explicitly.

## Parsing boundaries

Separate:

1. raw input
2. parsing/coercion
3. validation
4. normalized representation
5. domain behavior

Do not combine all five responsibilities into one method.

## Anti-patterns

- hidden coercion
- ambiguous nil/empty semantics
- deeply nested hashes with undocumented structure
- stringly-typed state
- primitive obsession without a domain reason
- data classes with no behavior when a simple hash would suffice
- domain behavior embedded in serializers/parsers

## Reference example

A value type: Struct with Comparable, frozen at construction, where equality follows field values rather than identity.

```ruby
Money = Struct.new(:cents, :currency) do
  include Comparable

  def self.of(amount, currency) = new((amount * 100).round, currency).freeze

  def +(other)
    raise "currency mismatch" unless currency == other.currency
    Money.new(cents + other.cents, currency).freeze
  end

  def <=>(other) = [cents, currency] <=> [other.cents, other.currency]
  def to_s = format("%.2f %s", cents / 100.0, currency)
end

price = Money.of(19.99, :eur)
raise "value equality broken" unless price == Money.of(19.99, :eur)
puts "#{price} + #{price} = #{price + price}"
```

## Agent review checklist

- [ ] value contract is explicit
- [ ] nil/empty distinction is intentional
- [ ] representation matches existing conventions
- [ ] external input is validated
- [ ] structured hashes have a defined shape
- [ ] value-object introduction is justified
- [ ] mutation and ownership are understood

## Verification

Test representative, empty, nil, malformed, and boundary values where those distinctions affect behavior. Test round-trip parsing/serialization when data crosses an external boundary.

## Source foundation

Derived from the data types and operations material in *The Ruby Workshop*. The naming and simplicity rules are reinforced by *Clean Ruby*: choose representations that help another developer understand the code without reconstructing hidden meaning.
