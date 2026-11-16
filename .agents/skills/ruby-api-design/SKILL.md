---
name: ruby-api-design
description: Use when designing Ruby methods, classes, services, or library boundaries whose public inputs, outputs, errors, visibility, or compatibility contract matter.
---

# Ruby API Design

## Purpose

Make public Ruby APIs predictable for both callers and future maintainers.

## Activate when

- introducing a public method or class
- changing parameters or return values
- designing a service/gem/library boundary
- callers branch on result types
- an API is used from multiple places
- compatibility with existing callers matters

## Repository inspection

Inspect:

- all current callers
- tests and fixtures
- visibility
- existing error/result conventions
- supported Ruby version
- documentation/examples if the API is externally consumed

## Decision rules

Prefer:

- explicit required arguments
- keyword arguments for semantically named options
- a predictable return type or narrow family such as Thing or nil
- domain-specific exceptions or result objects when multiple failure outcomes matter
- private helpers for implementation detail

Avoid:

- unrelated return types such as object/hash/false/string
- boolean flags that switch the public method into unrelated modes
- exposing internal hashes when a domain object has stable meaning
- changing a public return contract merely to simplify implementation

## Compatibility procedure

1. identify the current contract
2. list callers and observable behavior
3. define the intended contract
4. update tests at the public boundary
5. change implementation
6. verify failure and edge behavior
7. inspect downstream callers

## Failure modes

- accidental return-type widening
- exceptions introduced where callers expect nil/results
- optional parameters that silently alter old behavior
- public methods exposing internal state
- undocumented keyword/positional compatibility changes
- changing visibility during refactoring

## Reference example

A small public API surface with explicit keyword arguments, private collaborators, and a documented deprecation path.

```ruby
class ExchangeRate
  def initialize(fetcher:)          # collaborator injected, not global
    @fetcher = fetcher
  end

  def convert(amount, from:, to:, at: :latest)
    rate = @fetcher.rate(from, to)
    (amount * rate).round(2)
  end

  # Deprecated bridge kept for one minor release, then removed.
  def convert!(amount, from, to)
    warn "convert! is deprecated; use convert(amount, from:, to:)"
    convert(amount, from: from, to: to)
  end
  private attr_reader :fetcher
end

rates = Struct.new(:table) do
  def rate(from, to) = table[[from, to]]
end.new({ [:usd, :eur] => 0.92 })
api = ExchangeRate.new(fetcher: rates)
raise "wrong conversion" unless api.convert(100, from: :usd, to: :eur) == 92.0
puts api.convert(250, from: :usd, to: :eur)
```

## Agent review checklist

- [ ] public contract is explicit
- [ ] arguments are meaningful
- [ ] return behavior is predictable
- [ ] failures have an intentional contract
- [ ] visibility is deliberate
- [ ] callers were checked
- [ ] compatibility tests exist where needed

## Verification

Test successful results, invalid inputs, failure behavior, nil/empty behavior where applicable, and representative callers. For library APIs, verify the documented entry point independently of implementation classes.

## Source foundation

Grounded in the method, argument, return-value, and class API guidance in *Learn Rails 6*, with responsibility and readability principles from *Clean Ruby*.
