# Agent Engineering Contract

This repository is an agent-oriented Ruby/Rails skill library. Every coding agent working here must treat the skill library, pattern library, evaluation corpus, and validators as one system.

## Domain change contracts

Framework- and domain-specific rules (Active Record, Action Controller, Action Cable, authentication, authorization, caching, database, jobs, messaging, reliability, release, security, and the rest) live in the owning skill under a `## <Domain> changes` section, so they load only when that skill is routed. Route with `skill-manifest.yml` and `router/ROUTING.md`, then apply the owning skill's change contract in full. Keep authentication and authorization separate at every boundary.

## Operating sequence

1. **Discover** the applicable repository skills from `skill-manifest.yml`.
2. **Inspect** the repository, current implementation, tests, runtime/version constraints, and existing conventions before proposing a design.
3. **Resolve ambiguity** before changing code. Do not silently choose between conflicting requirements.
4. **Select patterns only when earned.** Existing repository patterns take precedence over generic preferences. A pattern is guidance, not a mandatory abstraction.
5. **Implement incrementally** in the smallest coherent slice.
6. **Test behavior** at the boundary that owns the contract.
7. **Lint the change** with the repository's RuboCop configuration when Ruby/Rails code is affected.
8. **Run security verification** for security-sensitive Ruby/Rails changes, using the configured scanners and abuse-case tests.
9. **Review the change** for correctness, simplicity, architecture, security, performance, and scope.
10. **Simplify** if an abstraction does not earn its complexity.
11. **Verify** with the repository's validators, focused tests, and applicable CI-equivalent checks.
12. **Report evidence**, not assumptions. Never claim a test, benchmark, CI run, or deployment passed unless it was actually observed.

## Context rules

- Read only the smallest useful source slice first; expand context when evidence requires it.
- Resolve Ruby/Rails versions from repository configuration rather than memory.
- Prefer official/source-backed guidance for framework-sensitive behavior.
- Treat `.rubocop.yml` as the executable Ruby/Rails style baseline; inspect plugin applicability before interpreting findings.
- Treat security scanner output as evidence requiring trust-boundary/data-flow analysis, not as an automatic verdict.
- Treat external input and third-party responses as untrusted at boundaries.
- Never weaken a validator or test merely to make an agent run green.
- Preserve public contracts unless the task explicitly changes them.

## Routing quality

- Treat trigger matching as an activation signal, not proof that a skill owns the task.
- Identify a primary skill from the dominant engineering boundary.
- Add secondary skills only for real dependent constraints or execution boundaries.
- Consult router/ROUTING.md and router/ROUTING_CASES.yml for overlap-heavy tasks.
- Keep authentication and authorization separate; identity establishment does not prove permission.
- For cross-boundary authorization, re-authorize at the execution boundary instead of inheriting trust from an earlier controller or request.
- Prefer composing existing skills over creating a new skill for every cross-cutting concern.

## Design rules

- Prefer the simplest implementation satisfying the contract.
- Reuse an existing repository abstraction before introducing a new one.
- Introduce POROs, services, strategies, adapters, policies, presenters, factories, or other patterns only when the responsibility or variation justifies the boundary.
- Keep domain behavior out of controllers/views when it does not belong there.
- Keep persistence integrity in database constraints where application validation alone cannot guarantee it.
- Do not create abstractions solely to satisfy a pattern vocabulary.

## Stack minimality

For Ruby + Rails + React + TypeScript + PostgreSQL changes:
- apply stack-minimality after identifying the domain skill that owns the contract;
- inspect existing code, dependencies, framework primitives, browser APIs, and PostgreSQL capabilities before adding abstraction or infrastructure;
- prefer the smallest coherent diff, not the smallest textual diff;
- preserve security, accessibility, boundary validation, database integrity, observability, and required tests;
- mark deliberate shortcuts with a concrete ceiling and revisit trigger;
- never report hypothetical line, token, cost, or performance savings as measured evidence;
- use stack-minimality-review for focused over-engineering review and stack-minimality-audit for repository-wide simplification audits.

## CI toolchain maintenance

For GitHub Actions changes:
- inspect the currently supported action runtime/version before changing a workflow;
- keep `actions/checkout` on the repository's Node 24-compatible major;
- run `ruby scripts/audit_ci_toolchain.rb` and `bin/validate`;
- do not treat a green workflow with deprecation warnings as a finished maintenance state when the warning has an actionable supported upgrade.

## Verification contract

A change is complete only when:
- relevant tests pass;
- validators pass;
- no accidental scope expansion is present;
- public contracts are preserved or intentionally updated;
- unrun checks are explicitly disclosed.

## Skill precedence

When multiple skills apply:

1. explicit task requirements
2. repository architecture and existing conventions
3. runtime/framework constraints
4. focused domain skill
5. design-pattern guidance
6. generic style preferences

When skills conflict, stop and resolve the conflict rather than combining incompatible rules.

## Skill-pack installation

- Treat installed skills and patterns as executable agent configuration.
- Review the requested repository/ref before installation and prefer immutable tags or commits for reproducible environments.
- Verify the installed pack with `bin/skill-pack-verify` before using it in a controlled benchmark.
- Do not mix skill packs from different revisions when collecting benchmark evidence; record the resolved Git SHA and manifest/routing hashes.
- Remove or replace obsolete skills through the installer rather than manually mutating the installation tree.

## Benchmark integrity

Evaluation fixtures and verifiers are measurement infrastructure. Do not make the evaluator easier by weakening constraints, accepting unverified output, or coupling the verifier to one agent's implementation. Public structural checks must be complemented by behavioral tests and, where appropriate, hidden/adversarial cases.

## Release and public-readiness changes

For final release or publication changes:
- keep README inventory, the current milestone in `docs/ITERATIONS.md`, manifest, router, validators, and CI evidence synchronized;
- record each iteration in `CHANGELOG.md` and `docs/ITERATIONS.md`, never in the README;
- require explicit public contribution and security entry points without inventing unsupported contact channels;
- keep changelog entries factual and scoped to repository changes actually implemented;
- do not commit generated benchmark outputs, credentials, local paths, or provider-specific secrets;
- run the release-readiness audit and the full canonical validator before calling the repository publication-ready.

## Evaluation and benchmark changes

For evaluation or benchmark changes:
- keep evaluation cases deterministic, source-traceable, and independent from one another;
- distinguish the public evaluation corpus from benchmark-measured fixture/campaign coverage;
- treat baseline versus skills-enabled comparisons as controlled paired experiments with identical runtime, fixture, verifier, and agent configuration unless a deliberate provider comparison is being run;
- require fresh workspaces for paired runs and preserve individual run evidence rather than reducing results to one score;
- keep hidden/adversarial benchmark cases outside the public repository and use the same evaluation/result protocol;
- validate fixture roots and implementation/test seams before treating a campaign as executable;
- preserve campaign version, source corpus, fixture/verifier identity, execution controls, and coverage provenance in aggregate results;
- never interpret benchmark smoke tests as evidence of model capability improvement; smoke tests establish harness integrity only;
- never weaken an evaluator, fixture, or verifier to make an agent pass.

## Repository completeness and framework drift changes

For changes to the skill repository itself:
- treat the manifest, router, validator, system-test suite, evaluations, benchmarks, README inventory, and agent guidance as one consistency surface;
- preserve one owning skill for a framework capability unless repository evidence justifies a new boundary;
- register every new artifact and make the canonical validator execute every repository system test;
- resolve current Rails behavior from the supported Rails version before adding triggers or guidance;
- treat Rails 8/8.1 additions such as ActiveJob::Continuable, structured Event Reporting, Local CI, Solid Cache/Cable, Kamal, and CLI credential fetching as version-sensitive framework concerns;
- do not claim repository completeness from counts alone; verify executable registration, routing, evaluation coverage, and regression tests.
