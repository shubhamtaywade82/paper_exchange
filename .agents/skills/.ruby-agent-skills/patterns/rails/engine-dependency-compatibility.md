---
name: engine-dependency-compatibility
description: Engine Dependency Compatibility Contract
family: rails
---
# Engine Dependency Compatibility Contract

## Problem
An engine gem can break hosts when its Ruby/Rails/dependency constraints do not match actual supported behavior.

## Use when
Changing engine dependencies, gemspec constraints, or supported Rails versions.

## Do not use when
No dependency or compatibility effect.

## Repository inspection
Inspect gemspec, Gemfile.lock, runtime requirements, engine dependencies, and support matrix.

## Implementation procedure
Declare accurate runtime constraints and test the supported matrix where required.

## Example

```ruby
# reports_engine.gemspec: declare what is actually tested in CI.
Gem::Specification.new do |spec|
  spec.name = "reports_engine"
  spec.version = "1.4.0"
  spec.summary = "Reporting engine"
  spec.authors = ["Platform team"]
  spec.files = Dir["{app,config,db,lib}/**/*", "README.md"]
  spec.required_ruby_version = ">= 3.2"
  spec.add_dependency "rails", ">= 7.1", "< 8.2" # CI matrix: 7.1, 7.2, 8.0, 8.1
end
```

## Failure modes
Dependency resolution failures, incompatible Rails APIs, and transitive conflicts.

## Testing
Run dependency resolution and compatibility tests for supported versions.

## Review checklist
[ ] Ruby constraint [ ] Rails constraint [ ] runtime deps [ ] matrix evidence

## Related skills
rails-engines-railties-engineering, ruby-runtime-compatibility