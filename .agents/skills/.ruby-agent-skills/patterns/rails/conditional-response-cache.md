---
name: conditional-response-cache
description: Use when a controller can safely use ETag or Last-Modified validators for conditional HTTP responses.
family: rails
---

# Conditional Response Cache

## Problem

Conditional GET can reduce response transfer and rendering work, but an incomplete validator can incorrectly reuse a representation across permissions, tenants, locales, or other variants.

## Use when

- adding fresh_when or stale
- adding ETag or Last-Modified
- reviewing 304 behavior
- coordinating controller responses with browser/proxy caching.

## Do not use when

- no meaningful validator exists
- private representation identity cannot be expressed safely.

## Repository inspection

Inspect authorization, locale, tenant/request context, response headers, CDN/proxy policy, and existing controller caching conventions.

## Implementation procedure

1. Define the representation's source-of-truth state.
2. Identify every dimension that changes the representation.
3. Choose weak/strong validator semantics appropriate to the response.
4. Set cache-control visibility deliberately.
5. Verify 200 and 304 behavior.
6. Re-check release/cache identity implications.

## Example

```ruby
class ReportsController < ApplicationController
  def show
    report = current_account.reports.find(params[:id])
    # The validator covers everything the response varies on: the record,
    # the viewer's permissions, and the locale.
    fresh_when etag: [report, current_user.permissions_version, I18n.locale], public: false
  end
end
```

## Failure modes

- shared validator for private representations
- omitting locale/tenant/permission dimensions
- treating 304 as proof that business state is globally unchanged
- making public caching the default for private data.

## Testing

Exercise matching and non-matching validators plus authorization and identity variants.

## Review checklist

- [ ] source-of-truth and identity are explicit
- [ ] validator semantics are appropriate
- [ ] cache visibility is intentional
- [ ] 304 behavior is tested
- [ ] private variants cannot collide

## Related skills

rails-action-controller, rails-caching, rails-security, rails-i18n
