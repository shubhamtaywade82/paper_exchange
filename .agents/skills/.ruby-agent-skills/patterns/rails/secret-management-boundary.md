---
name: secret-management-boundary
description: Govern secret storage, access, rotation, exposure, and revocation across Rails code, CI, runtime, logs, and integrations.
family: rails
---

# Secret Management Boundary

## Problem

Secrets are technically available to the application but become exposed through code, configuration, logs, payloads, or stale credentials.

## Use when

Adding provider credentials, signing keys, database credentials, API tokens, or encryption material.

## Do not use when

No secret or credential boundary changes.

## Repository inspection

Inspect Rails credentials, environment/container/CI secret stores, deployment manifests, logs, fixtures, scripts, integrations, and rotation procedures.

## Implementation procedure

1. Name the secret and owner.
2. Define storage location and access scope.
3. Minimize exposure to processes/code paths.
4. Prevent inclusion in logs/URLs/payloads.
5. Define rotation and revocation.
6. Verify deployment/CI access.
7. Add secret-scanning or regression checks where supported.
8. Remove stale credentials after rotation.

## Example

```ruby
# Access secrets at the point of use; do not copy them into long-lived globals, logs, or payloads.
class PaymentGatewayClient
  def initialize(api_key: Rails.application.credentials.dig(:payment_gateway, :api_key))
    @api_key = api_key
  end

  def inspect = "#<#{self.class.name}>" # keeps the key out of logs and error pages

  def charge(amount_cents:, idempotency_key:)
    Net::HTTP.post(URI("https://api.gateway.example/charges"),
                   { amount: amount_cents }.to_json,
                   "Authorization" => "Bearer #{@api_key}", "Idempotency-Key" => idempotency_key)
  end
end

Rails.application.config.filter_parameters += %i[api_key token secret authorization]
```

## Failure modes

- secret committed to source
- secret in exception/log context
- secret in message payload or query string
- broad runtime/CI access
- no rotation/revocation path
- test fixtures contain production-like credentials

## Testing

Exercise redaction, configuration validation, rotation path, and secret scanning according to repository tooling.

## Review checklist

- [ ] owner
- [ ] storage
- [ ] least-privilege access
- [ ] no logging/URL exposure
- [ ] rotation/revocation
- [ ] scanning/verification

## Related skills

- rails-security-engineering
- rails-security
- rails-production-runtime
