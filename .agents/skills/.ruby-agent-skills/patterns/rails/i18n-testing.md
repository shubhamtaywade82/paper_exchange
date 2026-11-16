---
name: i18n-testing
description: Test Rails localization deterministically across locale isolation, key coverage, interpolation, pluralization, formatting, fallback, URLs, jobs, and cache identity.
family: testing
---

# I18n Testing

## Problem

Localization regressions often pass default-locale tests while failing on locale resolution, grammar, formatting, async context, or cache isolation.

## Use when

- adding/changing localized behavior;
- reviewing translation coverage or fallback regressions.

## Do not use when

- the feature has no locale-dependent behavior.

## Repository inspection

Inspect test framework, locale fixtures, translation linting, supported locale list, request/job helpers, and cache tests.

## Implementation procedure

1. Scope locale per test.
2. Test resolution/unsupported values.
3. Test key/interpolation contracts.
4. Test pluralization and formatting.
5. Test localized URLs where applicable.
6. Test jobs/mailers/API behavior.
7. Test fallback/missing translations.
8. Test cache separation where applicable.

## Example

```ruby
require "test_helper"

class CartLocalizationTest < ActionDispatch::IntegrationTest
  test "renders pluralized Hindi copy from the user's locale" do
    sign_in users(:hindi_speaker)
    get cart_path
    assert_select "h1", I18n.t("cart.items", count: 2, locale: :hi)
  end

  test "rejects an unsupported locale param and falls back" do
    get cart_path(locale: "../../etc")
    assert_response :not_found # route constraint
  end

  test "job uses the recipient's locale, not the caller's" do
    I18n.with_locale(:en) do
      perform_enqueued_jobs { OrderShippedJob.perform_later(orders(:hindi_customer)) }
    end
    assert_match I18n.t("order_mailer.shipped.subject", locale: :hi), ActionMailer::Base.deliveries.last.subject
  end
end

# test_helper.rb: config.i18n.raise_on_missing_translations = true in config/environments/test.rb
```

## Failure modes

- global locale leakage between tests;
- default-locale-only coverage;
- full-page string snapshots;
- missing async locale tests;
- missing cross-locale cache tests.

## Testing

Prefer semantic key/behavior assertions and representative locale variants. Always restore locale state.

## Review checklist

- [ ] isolated locale
- [ ] supported/unsupported
- [ ] key/interpolation
- [ ] pluralization/formatting
- [ ] async boundaries
- [ ] fallback
- [ ] cache isolation

## Related skills

rails-i18n, rails-test-engineering, rails-active-job, rails-caching
