---
name: dependency-supply-chain
description: Review Ruby dependencies, build inputs, CI actions, and release artifacts as a security supply-chain boundary.
family: rails
---

# Dependency Supply Chain

## Problem

Application security can be compromised before runtime through vulnerable, malicious, or unexpectedly privileged dependencies and build components.

## Use when

Adding/upgrading gems, build plugins, CI actions, native dependencies, package sources, or release tooling.

## Do not use when

The dependency/build surface is unchanged.

## Repository inspection

Inspect lockfiles, dependency sources, native extensions, gem/plugin capabilities, CI workflows, release scripts, artifact provenance, update bots, and security scanners.

## Implementation procedure

1. Identify the new or changed dependency surface.
2. Verify source and version constraints.
3. Review transitive dependency changes.
4. Run repository-configured vulnerability auditing.
5. Review install/build scripts and CI permissions.
6. Check release artifact/provenance controls where available.
7. Add regression/allowlist documentation for accepted risks.
8. Verify rollback/removal path.

## Example

```bash
# Dependency changes are reviewed like code.
bundle exec bundler-audit check --update        # known vulnerable gems
git diff origin/main -- Gemfile.lock | grep -E '^\+    [a-z]' # which gems/versions changed
bundle exec rails runner 'puts Gem.loaded_specs.values.select { |s| s.extensions.any? }.map(&:full_name)' # native extensions to review
yarn npm audit --severity high
```

## Failure modes

- dependency added only for convenience with large transitive surface
- unreviewed install script/native extension
- compromised CI action with broad permissions
- vulnerability scanner ignored globally
- unpinned/unbounded dependency source
- security update breaks compatibility without rollout planning

## Testing

Run dependency/security scanners and verify the lockfile/build graph changes are intentional.

## Review checklist

- [ ] source verified
- [ ] transitive changes reviewed
- [ ] build/CI permissions reviewed
- [ ] vulnerability audit run
- [ ] accepted risk owned
- [ ] rollback/removal path

## Related skills

- rails-security-engineering
- rails-security
- ruby-runtime-compatibility
- rails-production-runtime
