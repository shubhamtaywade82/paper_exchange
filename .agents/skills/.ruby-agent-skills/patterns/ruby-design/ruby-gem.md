---
name: ruby-gem
description: Use when extracting reusable Ruby functionality into a gem with a deliberate public API, dependency boundary, test suite, and release contract.
family: ruby-design
---

# Ruby Gem Boundary

## Problem

Reusable Ruby code needs a narrow public API and reproducible dependencies rather than an application-specific pile of constants and internal paths.

## Use when

- packaging reusable library code
- extracting a stable integration/client from an application
- creating a new gem
- reviewing a gem's public surface

## Do not use when

- the code is only application-internal
- there is no stable reuse boundary
- a gem would merely rename a single application class

## Repository inspection

Inspect Gemfile/Gemspec, Ruby version, test framework, require paths, existing gem conventions, dependency policy, and release automation.

## Implementation procedure

1. define the public API
2. create a stable top-level namespace
3. separate public files from internal implementation
4. declare runtime dependencies explicitly
5. keep development dependencies separate where supported
6. make require paths deterministic
7. add unit/integration tests for public behavior
8. document configuration and error contracts
9. verify the gemspec builds cleanly

## Example

```ruby
# lib/money_format.rb — one public entry point, version in its own constant.
module MoneyFormat
  VERSION = "0.2.0"

  def self.cents(amount_cents, currency: "USD")
    format("%s %.2f", currency, amount_cents / 100.0)
  end
end

# money_format.gemspec
Gem::Specification.new do |spec|
  spec.name = "money_format"
  spec.version = MoneyFormat::VERSION
  spec.summary = "Format integer cents for display"
  spec.authors = ["Team"]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb"]
end
```

## Failure modes

- leaking application models/controllers into a library
- overly broad public API
- implicit dependencies
- require/load-order bugs
- environment-specific constants
- secrets or credentials in the gem
- tests coupled only to private internals

## Testing

Test the public require path and public API from a clean process. Build the gem and verify the package contains only intended files.

## Review checklist

- [ ] namespace is deliberate
- [ ] public entry point is stable
- [ ] dependencies are explicit
- [ ] load paths are deterministic
- [ ] application-specific code is excluded
- [ ] public API has tests
- [ ] gem build/package is verified

## Related skills

- ruby-gems-io-services
- ruby-api-design
- ruby-oop
- ruby-tdd-refactoring
