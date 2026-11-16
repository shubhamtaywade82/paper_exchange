---
name: builder
description: A staged construction object for complex object assembly.
family: ruby-design
---

# Builder

## Problem

A staged construction object for complex object assembly.

## Use when

Use when construction has many optional parts or ordered steps that make direct initialization unreadable.

## Do not use when

Do not use for ordinary keyword initialization.

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
Report = Data.define(:title, :sections, :footer)

# Staged construction: each step returns self; build validates and freezes.
class ReportBuilder
  def initialize
    @title = nil
    @sections = []
    @footer = nil
  end

  def title(text)
    @title = text
    self
  end

  def section(heading, body)
    @sections << { heading: heading, body: body }
    self
  end

  def footer(text)
    @footer = text
    self
  end

  def build
    raise ArgumentError, "title is required" if @title.to_s.empty?

    Report.new(title: @title, sections: @sections.dup.freeze, footer: @footer)
  end
end

report = ReportBuilder.new.title("Q3").section("Revenue", "Up 4%").footer("Draft").build
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
