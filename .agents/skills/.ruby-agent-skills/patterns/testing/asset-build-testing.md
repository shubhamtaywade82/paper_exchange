---
name: asset-build-testing
description: Test Rails asset builds as deterministic CI and deployment contracts.
family: testing
---
# Asset Build Testing

## Problem

Browser/system tests can pass while the actual release asset build is broken.

## Use when
Changing asset configuration, JavaScript/CSS build tooling, package dependencies, or release artifacts.

## Do not use when
The change cannot affect asset resolution or build output.

## Repository inspection
Inspect CI build stages, asset test helpers, package manager commands, Rails precompile, and system-test setup.

## Implementation procedure
Test clean installation, JS/CSS build, Rails asset precompile, and a production-like consumer path.

## Example

```bash
# CI step that exercises the real release asset path, not just a dev server.
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
test -s public/assets/.manifest.json
bin/rails test:system
```

## Failure modes
Testing only a watcher, relying on local caches, skipping precompile, and browser tests masking build failures.

## Testing
Run deterministic build/precompile checks and targeted system tests.

## Review checklist
[ ] clean build covered
[ ] precompile covered
[ ] production-like path covered
[ ] failure output is actionable

## Related skills
rails-asset-build-engineering, rails-test-engineering, rails-release-engineering
