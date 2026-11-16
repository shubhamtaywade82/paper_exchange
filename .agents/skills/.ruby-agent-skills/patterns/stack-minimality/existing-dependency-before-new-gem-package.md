---
name: existing-dependency-before-new-gem-package
description: Existing Dependency Before New Gem Or Package
family: stack-minimality
---
# Existing Dependency Before New Gem Or Package

## Problem
Every dependency adds supply-chain, upgrade, build, license, and failure surface.

## Use when
Considering a new gem, Rails plugin, npm package, or utility library.

## Do not use when
The existing stack lacks the capability or the new dependency materially improves a required boundary.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Inspect manifests and lockfiles, transitive dependencies, runtime support, and existing utilities before adding a dependency.

## Example

```ruby
# Gemfile before: gem "httparty" added for one GET.
# Gemfile after: nothing added; Faraday is already a dependency of the app.
response = Faraday.new(url: "https://status.example.test", request: { timeout: 2 }).get("/health")
healthy = response.success?

# Or, with no gem at all, the standard library:
require "net/http"
healthy = Net::HTTP.get_response(URI("https://status.example.test/health")).is_a?(Net::HTTPSuccess)
```

## Failure modes
Duplicate libraries, overlapping utilities, and lockfile churn for trivial features.

## Testing
Run dependency resolution and relevant tests/build checks after dependency changes.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
ruby-gems-io-services, rails-asset-build-engineering, stack-minimality
