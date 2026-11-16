# Skill Contract

A skill is an executable instruction set for an AI coding agent. It is not a chapter summary.

## Required frontmatter

Every skill starts with:

```yaml
---
name: stable-skill-id
description: One sentence describing when the skill should activate.
---
```

## Required sections

Every skill should contain:

1. Purpose
2. Activate when
3. Repository inspection
4. Decision rules
5. Implementation or review procedure
6. Anti-patterns / failure modes
7. Verification
8. Source foundation

Additional sections are encouraged when they improve execution, such as:
- input/output contracts
- compatibility rules
- examples
- performance constraints
- security checks
- framework-specific conventions
- troubleshooting

## Agent behavior

A coding agent using a skill should:

1. Inspect the repository before inventing structure.
2. Resolve the supported Ruby/Rails/runtime version.
3. Identify the smallest relevant scope.
4. Separate facts observed in the repository from assumptions.
5. Prefer existing conventions unless the task explicitly requires a change.
6. Make the smallest coherent implementation.
7. Add or update tests for behavior changes.
8. Run focused verification first, then regression verification.
9. Inspect the final diff for unrelated changes.
10. Report what was changed and what was actually verified.

## Evidence hierarchy

Use this order when deciding how the code should behave:

1. Explicit user requirements.
2. Existing repository behavior and tests.
3. Project configuration and dependency versions.
4. Established local conventions.
5. Source-backed skill rules.
6. General Ruby/Rails knowledge.

Never invent an API, class, route, schema field, callback, gem, or framework behavior merely because it would be conventional.

When evidence conflicts, call out the conflict and inspect more evidence before changing behavior.

## Version safety

A skill must not silently apply APIs from a newer Ruby or Rails version.

When a version is unknown:
- inspect `Gemfile`, `*.gemspec`, `Gemfile.lock`, `.ruby-version`, CI, Dockerfiles, and project metadata
- use only syntax and APIs supported by the resolved runtime
- verify version-sensitive behavior when it matters

## Cross-skill behavior

Skills are composable.

Examples:
- Rails endpoint + persistence change: `rails-architecture` + `rails-active-record` + `ruby-tdd-refactoring`
- Bug in a service object: implementation skill + `ruby-debugging` + `ruby-tdd-refactoring`
- Refactoring a metaprogrammed API: `ruby-metaprogramming` + `ruby-clean-code` + `ruby-tdd-refactoring`

Do not force a cross-cutting task into a single skill.

## Completion contract

A coding task is not complete merely because code was written.

Completion requires, where applicable:
- expected behavior implemented
- focused tests passing
- relevant regression tests passing
- lint/static checks passing when the repository uses them
- migrations/schema checks passing for database changes
- no unexplained test failures
- final diff reviewed for accidental scope expansion
