---
name: jsbundling-contract
description: Define a reproducible Rails JavaScript bundling boundary.
family: rails
---
# JS Bundling Contract

## Problem

JavaScript builds can succeed locally while CI or production lacks the runtime, dependency, or generated artifact.

## Use when
JavaScript requires compilation, transformation, package processing, bundling, or code splitting.

## Do not use when
Importmap or native browser modules fully satisfy the dependency contract.

## Repository inspection
Inspect package manager, lockfile, runtime version, bundler config, entrypoints, build script, CI, and deployment.

## Implementation procedure
Pin runtime/toolchain versions, define source and output boundaries, fail builds on compiler errors, and integrate the build into CI/release.

## Example

```yaml
# package.json scripts are the contract CI and production both run.
#   "scripts": { "build": "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets" }
# jsbundling-rails hooks `yarn build` into assets:precompile.

# .github/workflows/ci.yml (excerpt)
jobs:
  assets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - uses: actions/setup-node@v4
        with:
          node-version-file: .node-version
          cache: yarn
      - run: yarn install --frozen-lockfile
      - run: RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
      - run: test -s app/assets/builds/application.js
```

## Failure modes
Local-only builds, lockfile drift, missing native dependencies, silent compiler warnings, and stale artifacts.

## Testing
Run clean dependency installation and a production-like one-shot build.

## Review checklist
[ ] runtime pinned
[ ] lockfile authoritative
[ ] build command reproducible
[ ] CI executes it
[ ] output consumed by Rails

## Related skills
rails-asset-build-engineering, ruby-runtime-compatibility, rails-release-engineering
