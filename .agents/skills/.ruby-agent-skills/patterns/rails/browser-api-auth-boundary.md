---
name: browser-api-auth-boundary
description: Separate browser session authentication from API/token authentication so CSRF, cookie, expiry, and revocation semantics remain explicit.
family: rails
---

# Browser API Auth Boundary

## Problem

Browser sessions and machine/API credentials have different threat models. Reusing one mechanism blindly can weaken CSRF protection, token handling, or logout semantics.

## Use when

Adding JSON APIs, bearer authentication, service credentials, SPA endpoints, or mixed browser/API Rails applications.

## Do not use when

The entire application has one explicitly documented authentication mechanism.

## Repository inspection

Inspect routes, request formats, session middleware, CSRF configuration, API clients, token models, CORS, and authentication controllers.

## Implementation procedure

1. Classify each endpoint as browser, API, service, or mixed.
2. Identify credential type.
3. Define CSRF semantics.
4. Define credential expiry/revocation.
5. Define error responses.
6. Prevent credential leakage through URLs/logs.
7. Keep machine credentials out of browser session assumptions.
8. Test each boundary separately.

## Example

```ruby
# Browser: cookie session + CSRF. API: bearer token, no cookies, no CSRF.
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include Authentication # signed session cookie
end

class Api::BaseController < ActionController::API
  before_action :authenticate_token!

  private

  def authenticate_token!
    token = request.authorization.to_s.delete_prefix("Bearer ")
    @current_token = ApiToken.active.find_by_token_digest(Digest::SHA256.hexdigest(token)) || head(:unauthorized)
  end
end
```

## Failure modes

- disabling CSRF for all JSON endpoints
- bearer token treated like cookie session
- browser redirect response returned to API clients
- API token can call session-only endpoints without policy

## Testing

Test browser authenticated requests, API token requests, missing credentials, invalid tokens, CSRF behavior, and unauthorized responses.

## Review checklist

- [ ] endpoint classes identified
- [ ] credential type explicit
- [ ] CSRF semantics explicit
- [ ] expiry/revocation explicit
- [ ] wire failure contract tested

## Related skills

- rails-authentication
- rails-action-controller
- rails-api-integration
- rails-security

