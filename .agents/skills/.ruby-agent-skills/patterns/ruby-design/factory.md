---
name: factory
description: A construction boundary that selects or assembles an object based on explicit inputs.
family: ruby-design
---

# Factory

## Problem

A construction boundary that selects or assembles an object based on explicit inputs.

## Use when

Use when construction varies by type/configuration or object creation requires non-trivial assembly.

## Do not use when

Do not use as a wrapper around a one-line constructor.

## Repository inspection

Inspect existing objects that solve the same responsibility, naming and namespace conventions, construction boundaries, tests, and framework-specific conventions before introducing this pattern.

## Implementation procedure

1. Identify the responsibility and public contract.
2. Search the repository for an existing implementation or equivalent abstraction.
3. Define the smallest interface that solves the problem.
4. Keep collaborators explicit and follow local construction conventions.
5. Preserve existing behavior while introducing the boundary.
6. Add focused tests for the contract and important failure cases.
7. Remove duplication only after behavior is covered.
8. Inspect the final diff for unnecessary indirection.

## Example

```ruby
# Construction selected by explicit input; unknown input fails loudly.
module Exporters
  REGISTRY = {
    "csv" => CsvExporter,
    "json" => JsonExporter,
    "xlsx" => XlsxExporter
  }.freeze

  def self.for(format, **options)
    REGISTRY.fetch(format.to_s) { raise ArgumentError, "unsupported export format: #{format}" }.new(**options)
  end
end

exporter = Exporters.for(params[:format], timezone: current_user.time_zone)
```

## Failure modes

- applying the pattern because its name sounds sophisticated
- creating an abstraction around trivial code
- hiding dependencies or construction
- adding generic manager/processor classes
- changing behavior during an architectural refactor
- leaking framework or vendor details across the boundary

## Testing

Test the public contract first. Add focused collaborator tests where the pattern creates independently testable behavior. Keep integration tests for real framework or external boundaries.

## Review checklist

- Is the pattern justified by the problem shape?
- Is the interface smaller or clearer than the original coupling?
- Does it match repository conventions?
- Is construction explicit?
- Are failure cases covered?
- Would a simpler implementation be better?

## Related skills

- ruby-poro
- ruby-oop
- ruby-object-composition
- ruby-dependency-injection
- ruby-clean-code
- ruby-tdd-refactoring
