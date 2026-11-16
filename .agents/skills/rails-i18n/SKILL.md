---
name: rails-i18n
description: "Use when designing, implementing, reviewing, testing, or operating Rails internationalization/localization across locale selection, translation keys, pluralization, interpolation, dates/numbers, localized views/routes, model errors, mailers, APIs, jobs, caching, and translation backends."
---

# Rails I18n & Localization Engineering

## Purpose

Treat localization as a cross-layer application contract, not as a collection of translated strings.

Rails I18n provides a public API for translation and localization, locale configuration, permitted locales, default locale, translation load paths, and backend selection. Rails also integrates I18n with views, Active Model/validation errors, Active Record naming, Action Mailer subjects, and date/time formatting.

Core flow:

```text
define supported locale contract
-> resolve locale from a trusted source
-> establish request/job context
-> use stable translation keys
-> provide interpolation/pluralization/formats
-> render localized output
-> preserve locale across async/dependency boundaries
-> test fallback and isolation
-> observe missing/invalid translations
```

## Activate when

- adding or changing I18n.t, I18n.translate, I18n.l, or localize;
- adding locales or changing I18n.available_locales;
- changing I18n.default_locale or enforce_available_locales;
- selecting locale from URL, domain, subdomain, header, cookie, or user preference;
- localizing routes or URL generation;
- adding/changing translation files in config/locales;
- adding pluralized or interpolated translations;
- changing date, time, number, currency, or format localization;
- translating validation/model errors;
- localizing Action Mailer subjects/content;
- propagating locale through Active Job/background work;
- localizing API responses;
- deciding whether locale belongs in cache keys;
- adding custom I18n backends or database-backed translations;
- diagnosing missing translations, wrong locale, locale leakage, or inconsistent formatting;
- adding translation tests or translation linting.

Do not activate merely because a page contains one hard-coded string. Use the smallest relevant Rails view/controller skill for a trivial change when no localization contract is introduced.

## Repository inspection

Inspect before changing localization:

1. Ruby/Rails and I18n versions;
2. I18n.load_path, locale directory structure, and translation file conventions;
3. I18n.available_locales, default_locale, and enforce_available_locales;
4. existing locale-resolution code in controllers/middleware;
5. routes and URL generation conventions;
6. user/account locale preference storage and authorization;
7. request/job locale propagation;
8. Active Job serialization and locale behavior;
9. views/helpers/components using translation keys;
10. model validation/error translation conventions;
11. Action Mailer locale handling;
12. API serialization/error contracts;
13. cache keys and locale-sensitive cached representations;
14. fallback configuration and missing-translation handling;
15. custom backends or external translation stores;
16. tests, fixtures, translation linting, and CI checks;
17. source-control organization and translation ownership.

Do not introduce a second locale-resolution mechanism when the repository already has one.

## Locale contract

Define supported locales explicitly.

The contract should include:

- canonical locale identifiers;
- default locale;
- allowed locale sources;
- fallback behavior;
- invalid-locale behavior;
- persistence of user preference;
- URL representation where applicable;
- locale behavior for async jobs;
- locale behavior for system-generated messages.

Use I18n.available_locales as the application-level allowlist where appropriate.

Do not let arbitrary request input become a locale merely because a translation file happens to exist.

Normalize locale identifiers at the boundary and map browser/region variants to supported application locales intentionally.

## Locale resolution

Locale selection should happen once at a well-defined boundary.

Common sources:

- explicit URL path;
- domain/subdomain;
- authenticated user preference;
- trusted account/tenant setting;
- accepted language headers;
- explicit API parameter.

Define precedence.

Example:

```text
explicit URL locale
-> authenticated user preference
-> account/tenant default
-> negotiated request locale
-> application default
```

The exact order is application-specific. Inspect existing behavior before changing it.

Never trust a locale source blindly.

Reject or normalize unsupported values before entering the application locale context.

## Request locale isolation

Use request-scoped locale context.

Prefer I18n.with_locale around the request/unit of work instead of mutating I18n.locale without restoration.

Rails explicitly warns that assigning I18n.locale without consistent isolation can leak locale effects into later work on the same thread/process, and recommends I18n.with_locale for scoped changes.

The request lifecycle should look like:

```text
resolve locale
-> validate allowed locale
-> I18n.with_locale(locale)
-> controller/domain/rendering
-> restore prior locale
```

Do not rely on a global mutable locale remaining correct after arbitrary controller/service execution.

## Thread, fiber, and concurrency boundaries

Locale is execution context.

Inspect how the repository uses:

- threads;
- fibers;
- concurrent jobs;
- async Ruby/Rails work;
- request executors.

Never assume locale context automatically crosses an arbitrary concurrency boundary.

When spawning asynchronous work, pass locale explicitly when the work's user-facing output depends on locale.

Test that concurrent units do not cross-contaminate locale.

Compose with ruby-concurrency for custom concurrency and execution-context boundaries.

## Background jobs and locale propagation

A background job may execute after the request that enqueued it is gone.

For user-facing jobs define:

- which locale should be used;
- where the locale is captured;
- whether user/account preference should be re-read at execution time;
- behavior when the user's preference changed after enqueue;
- fallback when the locale is no longer supported.

Prefer reconstructible business identity over serializing unnecessary request state.

Do not assume the controller's I18n locale is still active when the job performs.

Compose with rails-active-job for enqueue, serialization, retry, and execution lifecycle.

## Translation key contract

Translation keys are application APIs.

Prefer stable semantic keys:

```yaml
en:
  accounts:
    lock:
      title: "Account locked"
      body: "..."
```

Avoid keys tied only to English source text unless the repository has an established convention.

Define ownership by domain/component where possible.

Do not scatter unrelated translations under generic global keys such as messages.success when multiple contexts require different semantics.

A key should have one clear responsibility.

Do not silently reuse a key because two English strings happen to be identical.

## Interpolation

Interpolation values are part of the translation contract.

Define:

- required variables;
- variable names;
- type/format expectations;
- escaping expectations;
- behavior when values are missing.

Keep translators responsible for grammar/order while application code supplies semantic values.

Prefer:

```yaml
en:
  greeting: "Hello %{name}"
```

over concatenating localized fragments in Ruby.

Do not build sentences by concatenating independently translated words when language grammar may differ.

Never expose secrets or sensitive identifiers through translation interpolation or logs.

## Pluralization

Pluralization is language-dependent and must be delegated to I18n pluralization rules.

Avoid count == 1 ? "item" : "items" when translated output is required.

Provide the count interpolation expected by the locale's pluralization rule.

Use explicit pluralization keys and test every supported locale's required forms.

Do not assume all locales have only singular/plural forms.

## Safe HTML translations

Translations can contain HTML markup in supported Rails view contexts.

Treat translated HTML as code that requires an explicit trust decision.

Do not mark arbitrary translated/user-provided strings as HTML-safe.

Keep trusted static markup in translation files only when repository conventions and escaping behavior make the contract clear.

Never combine translated strings with unescaped user input merely because the translation itself is trusted.

Coordinate with rails-security for XSS/escaping review.

## Date, time, number, and currency localization

Localize presentation values rather than storing localized representations as domain data.

Examples include:

- date/time formats;
- decimal separators;
- currency symbols/format;
- number delimiters;
- distance/measurement presentation.

Persist canonical values and render them through the locale-specific formatter.

Do not store "1,25" instead of a numeric value merely because one locale displays that representation.

Define timezone and locale separately:

```text
timezone = temporal context
locale = presentation/language context
```

Do not use locale as a substitute for timezone.

## Localized views and templates

Use localized view lookup when multiple templates differ structurally by locale.

Prefer translation keys for text changes and localized templates for genuinely structural differences.

Do not duplicate an entire view tree solely because a few strings differ.

For locale-specific assets/content, inspect caching and deployment implications.

Compose with rails-action-view for rendering boundaries.

## Localized routes and URLs

When locale appears in URLs, make it part of the routing contract.

Options include:

- path scope such as /:locale;
- optional locale scope;
- domain/subdomain;
- query parameter.

Keep the representation consistent.

Rails supports locale path scoping and default_url_options for propagating locale through generated URLs.

If locale comes from a path/domain, validate it against supported locales before switching context.

Do not accept arbitrary route locale values that create unbounded routing/caching dimensions.

## Locale negotiation

When deriving locale from browser headers or similar signals:

1. parse the external value;
2. normalize it;
3. map to supported application locales;
4. apply repository precedence;
5. fall back deterministically.

Do not expose the full browser locale space directly to the application.

For region-specific behavior, decide explicitly whether the application supports region-qualified locales such as en-US versus language-only en.

Rails' I18n approach permits locale forms beyond simple language identifiers, but the application must choose and configure its supported locale set intentionally.

## Model and validation translations

Rails integrates I18n with model names, attributes, and validation/error messages.

Keep domain validation logic independent from human-language presentation.

Do not parse translated error strings to make business decisions.

Prefer structured validation errors internally, then translate them at the presentation boundary.

For APIs, define whether clients receive:

- stable machine error codes;
- localized messages;
- both.

Do not make frontend logic depend on exact translated English text.

## API localization

Treat localized API responses as a wire-contract decision.

Define:

- how locale is supplied;
- which fields are localized;
- whether error messages are localized;
- content negotiation behavior;
- cache variation;
- client compatibility.

Prefer stable error codes plus localized human-readable messages where clients need to act programmatically.

If response representation changes by locale, include locale in any cache key/vary semantics.

Do not silently change API schema by locale.

Compose with rails-api-integration.

## Action Mailer localization

Mailer subjects and bodies are user-facing localized output.

Define:

- locale source;
- whether locale is captured or re-read;
- fallback;
- locale-specific templates/subjects;
- queue semantics.

Rails' I18n support includes Action Mailer email subjects.

Compose with rails-action-mailer and rails-active-job.

Do not let mailer templates guess the locale independently from the message's business context.

## Caching and locale

Locale is part of the cache identity whenever the rendered or computed result changes by locale.

Inspect:

- translation-dependent fragment caches;
- low-level caches returning localized strings;
- API response caches;
- CDN/Vary behavior;
- cache key dimensions.

A localized representation must not be served to a different locale merely because the resource identity matches.

Compose with rails-caching.

Do not add locale to every cache key by default if the cached value is deliberately locale-independent.

## Translation file organization

Choose a predictable locale tree.

Common dimensions:

- locale;
- domain/component;
- view/model/controller context.

Keep locale files small enough to review and merge safely.

Use a stable naming convention across teams.

Do not duplicate the same semantic key across multiple files with conflicting definitions without knowing load-order behavior.

Rails automatically includes .rb and .yml files from config/locales in the translation load path by convention.

When customizing I18n.load_path, verify ordering and override semantics.

## Missing translations

Define the production contract for missing keys.

Possible approaches:

- fail loudly in development/test;
- report missing translations;
- deterministic fallback;
- explicit placeholder;
- custom exception handler.

Do not silently hide large classes of missing translations in CI.

A missing translation in a security, billing, compliance, or transactional message may be more serious than a cosmetic missing string.

Instrument repeated/missing key patterns when operationally useful.

Never log sensitive interpolation values while diagnosing missing translations.

## Fallback behavior

Fallback is a product and correctness decision.

Define:

- fallback locale;
- fallback chain;
- locale-specific fallback;
- behavior for missing pluralization forms;
- behavior when locale is unsupported;
- whether fallback is permitted for all domains.

Do not assume the default locale is always a safe fallback for every message.

For high-risk user-facing workflows, test the actual fallback path.

## Custom backends

Rails supports replacing the default I18n backend with another backend, including database-backed or GetText-like stores.

Use a custom backend only when repository requirements justify it.

Inspect:

- read latency;
- caching;
- deployment consistency;
- write/update lifecycle;
- invalidation;
- versioning;
- availability;
- failure behavior;
- security/authorization for translation administration.

Do not move translation lookup into a database without understanding the runtime dependency introduced into rendering/request paths.

## Translation administration

If translations are editable by privileged operators, treat them as application configuration/data with authorization controls.

Review:

- who can edit;
- audit history;
- approval/review;
- rollback;
- locale/key validation;
- HTML safety;
- interpolation variable validation;
- publication semantics.

Do not let arbitrary users inject HTML into trusted translation contexts.

## Performance

Translation lookup is usually cheap, but high-cardinality dynamic backends or excessive repeated interpolation can become a measurable cost.

Measure before optimizing.

Inspect:

- backend calls per request;
- database-backed translation queries;
- translation cache hit rate;
- eager versus lazy loading;
- large locale files;
- repeated formatting work.

Do not memoize translations in request-global or process-global state without locale awareness.

## Security and privacy

Localization can become a data-exfiltration path when translated content contains sensitive interpolation values or privileged administrative content.

Review:

- translated HTML;
- interpolation values;
- locale-selection input;
- translation administration;
- custom backend authorization;
- logs/error reports;
- cache keys and localized content;
- tenant/account-specific translations.

A locale is presentation context, not authorization.

Never use locale choice to select tenant access or privileged data without an independent authorization boundary.

## Testing

Test the localization contract at the smallest relevant boundaries:

- supported/unsupported locale resolution;
- request locale isolation;
- translation lookup/key presence;
- interpolation requirements;
- pluralization;
- date/time/number formatting;
- model validation error translations;
- localized routes/URLs;
- mailer locale behavior;
- job locale propagation;
- API locale behavior;
- cache locale isolation;
- missing-translation handling;
- fallback behavior;
- custom backend failure when applicable.

Run locale-sensitive tests without leaking global locale between examples.

Test at least the representative locale variants whose grammar/formatting differs from the default locale.

Do not assert entire translated documents when a stable key/semantic fragment is sufficient.

## Reference example

All user-visible strings through I18n with lazy-lookup keys, plus locale-aware formatting for numbers and dates.

```ruby
class InvoicesController < ApplicationController
  def create
    if @invoice.save
      redirect_to @invoice, notice: t(".created", reference: @invoice.reference)
    else
      flash.now[:alert] = t(".rejected")
      render :new, status: :unprocessable_entity
    end
  end
end

# config/locales/en.yml:
#   en:
#     invoices:
#       create:
#         created: "Invoice %{reference} issued."
#         rejected: "We could not issue this invoice."
#
# Locale-aware presentation:
#   l(invoice.due_on)                 # -> "2026-09-30" per locale format
#   number_to_currency(cents / 100.0) # -> "19,99 EUR" per locale
```

## Agent review checklist

- [ ] supported locales explicit
- [ ] locale precedence explicit
- [ ] untrusted locale input validated
- [ ] request locale scoped with restoration
- [ ] concurrency boundaries reviewed
- [ ] job locale behavior explicit
- [ ] translation keys semantic/stable
- [ ] interpolation contract explicit
- [ ] pluralization delegated to I18n
- [ ] date/time/number presentation localized
- [ ] localized routes/URLs reviewed
- [ ] model errors/API error contract reviewed
- [ ] mailer locale behavior reviewed
- [ ] locale-sensitive caches reviewed
- [ ] missing/fallback behavior explicit
- [ ] custom backend justified when used
- [ ] translation administration secured when present
- [ ] translation tests deterministic
- [ ] sensitive interpolation/logging reviewed

## Anti-patterns / failure modes

- mutating I18n.locale globally without restoration;
- trusting arbitrary request locale input;
- treating locale as authorization;
- concatenating translated fragments into sentences;
- manually implementing pluralization;
- using translated messages as machine-readable API identifiers;
- storing localized presentation values as canonical domain data;
- using locale to infer timezone;
- caching localized output without locale identity;
- caching locale-independent values with unnecessary locale dimensions;
- translating security/business state by parsing human-readable strings;
- exposing privileged translation administration to untrusted users;
- allowing user HTML through trusted translation-safe paths;
- hiding missing translations in all environments;
- database-backed translation lookup without availability/capacity analysis;
- assuming locale context automatically crosses background/concurrent boundaries.

## Verification

For a localization feature:

```text
supported locale contract
-> trusted locale resolution
-> scoped execution context
-> translation/formats contract
-> cross-boundary propagation
-> fallback/missing-key behavior
-> focused locale tests
-> security/cache/API review
-> regression suite
```

For localization incidents distinguish:

```text
locale resolution
-> locale availability
-> translation lookup
-> interpolation/pluralization
-> formatting
-> route/rendering
-> cache
-> job/mail/dependency propagation
```

Never claim complete localization coverage merely because every visible English string has a translation file entry. Verify execution paths, fallback behavior, formatting, and cross-boundary locale propagation.

## Source foundation

Primary Rails source:

- https://guides.rubyonrails.org/i18n.html

Current guide evidence used by this skill includes locale configuration/availability, request-scoped I18n.with_locale, localized routes/URLs, translation keys, pluralization, model errors, Action Mailer subjects, locale files, and custom backends.

Composed repository skills:

- skills/rails-action-view/SKILL.md
- skills/rails-routing/SKILL.md
- skills/rails-validations/SKILL.md
- skills/rails-api-integration/SKILL.md
- skills/rails-action-mailer/SKILL.md
- skills/rails-active-job/SKILL.md
- skills/rails-caching/SKILL.md
- skills/rails-security/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/rails-test-engineering/SKILL.md
- skills/ruby-concurrency/SKILL.md

## Rails I18n changes

For I18n/localization changes:
- inspect supported locales, default locale, locale resolution, translation file organization, route conventions, user/account locale preferences, jobs, mailers, APIs, caches, tests, and custom backends before implementation;
- define supported locales and precedence explicitly; normalize/reject untrusted locale input before entering the scoped locale context;
- use request-scoped I18n.with_locale rather than leaking mutable I18n.locale across requests or execution units;
- keep locale separate from authentication/authorization and timezone; locale is presentation context, not authorization.
- use semantic translation keys with explicit interpolation contracts; do not use human-readable translated text as machine-readable identifiers;
- delegate pluralization and locale-aware date/number/currency formatting to I18n rather than hand-building grammar or presentation strings;
- review localized routes/default_url_options and bound locale dimensions when locale participates in URLs;
- explicitly decide whether background work captures or re-reads locale and validate locale again at execution;
- include locale in cache identity only when the cached representation actually varies by locale;
- treat translated HTML, interpolation data, translation administration, and localized caches as security boundaries;
- keep canonical domain data locale-independent and translate at presentation/wire boundaries;
- define missing-translation and fallback behavior for development, test, and production;
- use deterministic locale-sensitive tests and restore locale state between examples;
- never claim localization coverage solely from translation-file presence; verify execution paths, formatting, fallback, and cross-boundary propagation.
