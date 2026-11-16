---
name: serializable-hash-allowlist
description: Serializable Hash Allowlist
family: rails
---
# Serializable Hash Allowlist

## Problem
Broad attribute dumps expose fields and couple consumers to model schema.

## Use when
Using ActiveModel serialization or serializable_hash for an external representation.

## Do not use when
A trusted debugging-only representation with no consumer contract.

## Repository inspection
Inspect attributes, model columns, serialization options, and consumer expectations.

## Implementation procedure
Prefer explicit fields or only-style allowlists; use exclusions only when stable and audited.

## Example

```ruby
class Product < ApplicationRecord
  PUBLIC_FIELDS = %i[id name price_cents currency].freeze

  def as_json(options = nil)
    super({ only: PUBLIC_FIELDS, methods: [] }.merge(options || {}))
  end
end

Product.first.as_json
# => { "id" => 1, "name" => "Mug", "price_cents" => 49900, "currency" => "INR" }
# A new column (e.g. cost_price_cents) stays private until added to PUBLIC_FIELDS.
```

## Failure modes
Sensitive or newly added database columns silently become serialized fields.

## Testing
Test added and removed model columns against expected output.

## Review checklist
[ ] allowlist preferred [ ] output tested [ ] schema independence

## Related skills
rails-serialization-globalid-engineering, rails-active-model