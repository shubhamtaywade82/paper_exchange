---
name: credentials-testing-contract
description: Credentials and Encryption Testing Contract
family: rails
---
# Credentials and Encryption Testing Contract

## Problem
Security behavior is easily untested when tests require real secrets or assert implementation details instead of contracts.

## Use when
Adding or changing credentials/encryption behavior.

## Do not use when
Purely unrelated application tests.

## Repository inspection
Inspect test credentials, CI secret availability, fixtures, helper setup, filtering assertions, and production-like boot tests.

## Implementation procedure
Use disposable test keys/credentials, contract-level assertions, and failure-path tests; never reuse production secrets.

## Example

```ruby
class WebhookSignatureTest < ActiveSupport::TestCase
  # Synthetic secret: the test proves the contract without real credentials.
  SECRET = "whsec_test_only"

  test "accepts a valid signature and rejects a tampered body" do
    body = %({"id":"evt_1"})
    signature = OpenSSL::HMAC.hexdigest("SHA256", SECRET, body)
    verifier = WebhookVerifier.new(secret: SECRET)

    assert verifier.valid?(body, signature)
    refute verifier.valid?(body.sub("evt_1", "evt_2"), signature)
  end

  test "missing production key fails closed" do
    assert_raises(KeyError) { WebhookVerifier.from_credentials(credentials: {}) }
  end
end
```

## Failure modes
Tests depend on developer-local keys, leak values in failures, or pass despite missing production configuration.

## Testing
Run isolated tests with synthetic secrets and verify tests fail safely when required keys are absent.

## Review checklist
[ ] synthetic secrets [ ] missing-key path [ ] filtering [ ] no value assertions

## Related skills
rails-encryption-credentials-engineering, rails-test-engineering