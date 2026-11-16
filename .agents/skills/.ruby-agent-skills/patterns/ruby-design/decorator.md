---
name: decorator
description: An object that wraps a stable interface to add behavior without changing the wrapped object.
family: ruby-design
---

# Decorator

## Problem

An object that wraps a stable interface to add behavior without changing the wrapped object.

## Use when

Use when behavior should be layered dynamically around an existing contract.

## Do not use when

Do not use when inheritance or a direct method is simpler and stable.

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
# Adds caching around any object that responds to #fetch(key), without
# changing the wrapped object or its interface.
class CachingDirectory
  def initialize(directory, cache:)
    @directory = directory
    @cache = cache
  end

  def fetch(key)
    @cache.fetch("directory:#{key}") { @directory.fetch(key) }
  end
end

directory = CachingDirectory.new(LdapDirectory.new, cache: Rails.cache)
directory.fetch("sam") # same contract as LdapDirectory#fetch
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
