---
name: rubocop-review
description: Apply RuboCop and applicable extension plugins to a Ruby/Rails review without over-enabling plugins or blindly accepting lint findings.
family: tooling
---

# RuboCop Review

## Problem

A Ruby/Rails change needs static-analysis review, or a RuboCop finding needs interpretation and remediation.

## Use when

- configuring RuboCop
- selecting RuboCop plugins
- fixing RuboCop findings
- adding RuboCop to CI
- reviewing a RuboCop autocorrect diff

## Do not use when

- the task has no Ruby code or Ruby static-analysis boundary
- a non-Ruby linter is the only relevant tool

## Procedure

1. Inspect Ruby/Rails versions and Gemfile.lock.
2. Inspect existing .rubocop.yml and CI commands.
3. Determine which RuboCop plugins are actually applicable.
4. Prefer the modern plugin API for compatible extensions.
5. Run focused RuboCop checks.
6. Interpret each finding against repository conventions and behavior.
7. Apply the smallest justified fix.
8. Run tests for behavior changes.
9. Run broader RuboCop/CI-equivalent checks.
10. Review the final diff for accidental autocorrect churn.

## Plugin selection

Use data/rubocop/plugins.yml as the repository catalog. Never treat its existence as a mandate to install all plugins.

## Example

```bash
# 1. Confirm each extension supports the plugin API before listing it under
#    `plugins:` (legacy extensions need `require:`).
bundle exec ruby -e 'puts Gem.loaded_specs["rubocop-rails"].metadata["default_lint_roller_plugin"]'

# 2. Load only plugins for frameworks the repository uses (.rubocop.yml):
#      plugins:
#        - rubocop-performance
#        - rubocop-rails
#        - rubocop-minitest

# 3. Review findings for the changed files only, then decide each one.
bundle exec rubocop $(git diff --name-only --diff-filter=AM origin/main -- '*.rb')

# 4. Autocorrect only safe, behaviour-neutral cops, and review the diff.
bundle exec rubocop -a --only Layout/SpaceAfterComma,Layout/EmptyLineAfterGuardClause app/models/order.rb
git diff --stat

# 5. Adopt RuboCop on an existing codebase with a baseline instead of a mass rewrite.
bundle exec rubocop --auto-gen-config --no-exclude-limit
```

## Failure modes

- enabling every plugin
- using a plugin that does not match the repository technology
- introducing incompatible plugin versions
- using deprecated loading instructions without checking compatibility
- applying broad unsafe autocorrection
- disabling many cops instead of addressing the actual cause
- changing behavior just to satisfy a style preference
- treating a performance/style cop as an unconditional architecture rule

## Verification

- focused RuboCop run
- relevant tests
- full RuboCop run when appropriate
- final diff inspection

## Repository inspection

Inspect Ruby/Rails versions, Gemfile.lock, .rubocop.yml, CI lint commands, and actual plugin dependencies before changing configuration.

## Implementation procedure

Follow the smallest plugin/configuration change justified by repository evidence; run focused linting, tests when behavior changes, then broader lint checks.

## Testing

Run focused tests for behavior changes and the configured RuboCop command. Review autocorrect diffs before accepting them.

## Review checklist

- [ ] target runtime/version resolved
- [ ] applicable plugin support verified
- [ ] finding interpreted in context
- [ ] autocorrect diff reviewed
- [ ] broader lint check considered

## Related skills

- rubocop
- ruby-clean-code
- ruby-tdd-refactoring
- ruby-runtime-compatibility
