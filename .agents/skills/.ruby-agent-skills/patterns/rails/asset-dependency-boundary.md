---
name: asset-dependency-boundary
description: Keep frontend dependency installation, runtime versions, and Rails integration explicit.
family: rails
---
# Asset Dependency Boundary

## Problem

Frontend dependency changes can alter runtime, install, build, and supply-chain behavior outside the immediate feature.

## Use when
Adding/updating npm/Bun/yarn/pnpm packages or JavaScript/CSS build runtimes.

## Do not use when
The change is internal application code with no dependency graph change.

## Repository inspection
Inspect package manager, lockfile, runtime version, install scripts, registry configuration, and CI.

## Implementation procedure
Change the smallest dependency set, preserve lockfile integrity, audit install/build scripts, and verify clean installation.

## Example

```bash
# Review a frontend dependency change like any other runtime change.
git diff origin/main -- package.json yarn.lock | head -50   # what exactly changed
yarn npm audit --severity high                                 # known vulnerabilities
yarn why left-pad                                              # who pulls a new transitive dep
grep -n '"postinstall"\|"preinstall"' node_modules/new-package/package.json && echo "review install scripts"
```

## Failure modes
Transitive drift, malicious install scripts, incompatible runtime versions, and undocumented private registry assumptions.

## Testing
Run clean dependency installation and the relevant asset build.

## Review checklist
[ ] lockfile updated intentionally
[ ] runtime compatible
[ ] install scripts reviewed
[ ] CI clean install verified

## Related skills
rails-asset-build-engineering, rails-security-engineering, ruby-runtime-compatibility
