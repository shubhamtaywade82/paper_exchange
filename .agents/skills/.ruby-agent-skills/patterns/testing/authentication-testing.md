---
name: authentication-testing
description: Build deterministic transition-focused tests for login, session lifecycle, recovery, revocation, abuse controls, and authentication boundaries.
family: testing
---

# Authentication Testing

## Problem

Authentication regressions often pass happy-path tests while breaking expiry, revocation, fixation, recovery, or alternate execution paths.

## Use when

Changing authentication behavior or adding security controls around identity.

## Do not use when

The change has no authentication or identity semantics.

## Repository inspection

Inspect authentication helpers, request/system test conventions, factories/fixtures, mailer/job fakes, time helpers, token stores, and security tooling.

## Implementation procedure

1. Test the smallest identity boundary.
2. Add happy-path and rejection-path tests.
3. Cover session state transitions.
4. Cover fixation/rotation where relevant.
5. Cover logout and revocation.
6. Cover reset token expiry/replay.
7. Cover abuse thresholds.
8. Cover browser/API separation.
9. Cover alternate job/realtime paths.
10. Keep tests deterministic and secret-safe.

## Example

```ruby
class SessionsTest < ActionDispatch::IntegrationTest
  test "login rotates the session id" do
    get new_session_path
    pre_login_id = session.id

    post session_path, params: { email: users(:sam).email, password: "secret-password" }

    assert_redirected_to root_path
    refute_equal pre_login_id, session.id
  end

  test "expired password reset token is rejected" do
    token = users(:sam).generate_token_for(:password_reset)
    travel 16.minutes do
      patch password_path(token), params: { password: "new-password-123" }
    end
    assert_response :unprocessable_content
  end

  test "logout revokes the server-side session" do
    sign_in users(:sam)
    session_record = Session.last
    delete session_path
    assert session_record.reload.revoked_at
  end
end
```

## Failure modes

- only tests successful login
- no stale/revoked-session test
- reset token can be replayed
- test suite requires live email/OAuth/Redis
- assertions inspect private token values instead of security properties

## Testing

Prefer request/system tests for observable security contracts and narrow unit tests for pure token/policy logic.

Use deterministic time helpers for expiry.

Never print real credentials or raw tokens in failure output.

## Review checklist

- [ ] login success/failure
- [ ] session lifecycle
- [ ] fixation/rotation
- [ ] logout/revocation
- [ ] recovery
- [ ] abuse controls
- [ ] boundary separation
- [ ] deterministic dependencies
- [ ] no secret leakage

## Related skills

- rails-authentication
- rails-test-engineering
- rails-security
- ruby-tdd-refactoring
