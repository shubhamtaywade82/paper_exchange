---
name: asset-build-production-parity
description: Verify development and production asset contracts remain intentionally aligned.
family: rails
---
# Asset Build Production Parity

## Problem

Development and production can silently use different toolchains, dependencies, or artifact paths.

## Use when
A build works locally but production has a different compilation, runtime, or delivery path.

## Do not use when
Development and production intentionally share the exact same build path and no change affects parity.

## Repository inspection
Inspect development watchers, production build commands, Docker/CI, environment variables, CDN/cache behavior, and Rails boot.

## Implementation procedure
Document intentional differences and run the production build in a production-like environment.

## Example

```bash
# CI runs the same asset command and environment as the production image.
export RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 NODE_ENV=production
corepack enable && yarn install --immutable
bin/rails assets:precompile
test -f public/assets/.manifest.json || { echo "no asset manifest"; exit 1; }
```

## Failure modes
Dev-only dependencies, missing production binaries, environment-specific module resolution, and stale artifacts.

## Testing
Execute the release-relevant build in CI or a production-like container.

## Review checklist
[ ] differences intentional
[ ] production command tested
[ ] artifact consumed by Rails
[ ] environment assumptions documented

## Related skills
rails-asset-build-engineering, rails-production-runtime, rails-release-engineering
