---
name: serialization-versioning-contract
description: Serialization Versioning Contract
family: rails
---
# Serialization Versioning Contract

## Problem
Changing a serialized field's meaning or removing it can break consumers independently of application deploys.

## Use when
Changing externally consumed payload shape or semantics.

## Do not use when
Purely internal hashes with no persisted or external consumers.

## Repository inspection
Inventory API clients, jobs, stored payloads, fixtures, caches, and integrations.

## Implementation procedure
Classify additive versus breaking changes; use compatibility windows or explicit versions and deprecation rules.

## Example

```ruby
# Additive change: new field, old fields unchanged in meaning -> same version.
# Breaking change (rename/remove/re-mean a field) -> new version, old one kept until clients move.
module Api
  module V1
    class OrderJson
      def self.call(order) = { id: order.public_id, total_cents: order.total_cents }
    end
  end

  module V2
    class OrderJson
      # total is now an object with currency; v1 clients keep total_cents.
      def self.call(order) = { id: order.public_id, total: { amount: order.total_cents, currency: order.currency } }
    end
  end
end
# Contract tests pin both: assert_equal %w[id total_cents], Api::V1::OrderJson.call(order).keys.map(&:to_s)
```

## Failure modes
Silent semantic drift, old consumers failing, replay incompatibility.

## Testing
Test supported old and new fixtures and representative consumers.

## Review checklist
[ ] consumers [ ] compatibility window [ ] versions [ ] deprecation

## Related skills
rails-serialization-globalid-engineering, rails-api-integration, rails-release-engineering