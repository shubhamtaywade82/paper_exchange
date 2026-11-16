---
name: cache-key-isolation
description: Define cache-key identity so tenant, user, authorization, locale, resource, and representation boundaries cannot collide.
family: rails
---

# Cache Key Isolation

## Problem

A cache can return a correct value for the wrong principal, tenant, locale, resource, or representation when a required identity dimension is missing from the key.

## Use when

- a cache stores user-, tenant-, permission-, locale-, or resource-dependent values;
- response or computed-value semantics change by actor or scope;
- reviewing a suspected cross-tenant or cross-user cache leak.

## Do not use when

- the cached value is intentionally public and invariant across all callers;
- another existing repository contract already owns the complete key identity.

## Repository inspection

Inspect authentication/authorization, tenant resolution, locale handling, resource identity, feature/configuration inputs, cache namespace/versioning, and existing key helpers.

## Implementation procedure

1. Enumerate every input that changes the valid output.
2. Classify each as identity, authorization, representation, or calculation version.
3. Include required dimensions in a deterministic key.
4. Keep keys bounded and free of secrets.
5. Test two callers with different required identities.
6. Test version/representation changes.

## Example

```ruby
# The rendered dashboard varies by account, role, and locale; all three are
# in the key, plus a version for the template.
def dashboard_cache_key(user)
  ["dashboard", "v3", user.account_id, user.role, I18n.locale, user.account.updated_at.to_i]
end

Rails.cache.fetch(dashboard_cache_key(current_user), expires_in: 10.minutes) do
  render_to_string(partial: "dashboards/summary", locals: { account: current_user.account })
end
```

## Failure modes

- missing tenant/account identity;
- missing authorization scope;
- locale collisions;
- representation/schema collisions;
- raw sensitive data in keys;
- inconsistent key construction across call sites.

## Testing

Assert that distinct required identities produce distinct entries and that equivalent identities use the same key.

## Review checklist

- [ ] identity dimensions enumerated
- [ ] tenant/user/authorization scope included where required
- [ ] representation/version included
- [ ] no secrets
- [ ] collision/isolation tests exist

## Related skills

rails-caching, rails-security, rails-security-engineering, rails-authentication, rails-test-engineering
