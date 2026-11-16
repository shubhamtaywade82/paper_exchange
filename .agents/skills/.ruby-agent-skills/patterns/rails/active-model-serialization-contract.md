---
name: active-model-serialization-contract
description: Define explicit serialization fields and privacy rules for Active Model objects crossing application or API boundaries.
family: rails
---

# Active Model Serialization Contract

## Problem

Model-like objects are easy to serialize too broadly, exposing internal or sensitive attributes.

## Use when

- using ActiveModel::Serialization;
- exposing serializable_hash or JSON representations;
- passing Active Model state across boundaries.

## Do not use when

- serialization is not a public or durable boundary.

## Repository inspection

Inspect API serializers, job payloads, existing serialization methods, sensitive fields, and compatibility tests.

## Implementation procedure

1. Define the representation.
2. Declare explicit serialized attributes.
3. Add only intentional computed fields.
4. Exclude secrets/private fields.
5. Version or stabilize the contract when external consumers depend on it.
6. Test positive and negative serialization cases.

## Example

```ruby
class AccountSummary
  include ActiveModel::Serializers::JSON

  attr_accessor :id, :name, :plan, :api_token

  def initialize(id:, name:, plan:, api_token:)
    @id, @name, @plan, @api_token = id, name, plan, api_token
  end

  # The serializable attributes are an explicit allowlist; api_token is never
  # included, even though it is an attribute of the object.
  def attributes = { "id" => nil, "name" => nil, "plan" => nil }
end

AccountSummary.new(id: 1, name: "Acme", plan: "pro", api_token: "secret").to_json
# => {"id":1,"name":"Acme","plan":"pro"}
```

## Failure modes

- all attributes serialized accidentally;
- sensitive fields exposed;
- computed method leaks privileged state;
- serialization shape changes silently.

## Testing

Assert exact intended fields and absence of sensitive fields.

## Review checklist

- [ ] fields explicit
- [ ] sensitive attributes excluded
- [ ] representation ownership clear
- [ ] compatibility tested

## Related skills

- skills/rails-active-model/SKILL.md
- skills/rails-api-integration/SKILL.md
- skills/rails-security-engineering/SKILL.md
