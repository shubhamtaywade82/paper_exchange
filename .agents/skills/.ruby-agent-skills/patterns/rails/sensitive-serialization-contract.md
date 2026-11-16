---
name: sensitive-serialization-contract
description: Sensitive Serialization Contract
family: rails
---
# Sensitive Serialization Contract

## Problem
Sensitive model attributes can escape through serialized payloads despite secure storage.

## Use when
Serializing authentication, credential, private metadata, or security-sensitive model fields.

## Do not use when
The field is intentionally public and documented as such.

## Repository inspection
Inspect model attributes, encryption, authentication data, logs, API schemas, and consumers.

## Implementation procedure
Create an explicit allowlist and prove sensitive fields are absent unless justified by contract.

## Example

```ruby
class User < ApplicationRecord
  has_secure_password
  encrypts :phone_number

  # Excluded from inspect, logs, and error pages.
  self.filter_attributes += %i[password_digest phone_number otp_secret]

  # Default JSON excludes secrets even if a caller forgets an allowlist.
  def serializable_hash(options = nil)
    super({ except: %i[password_digest otp_secret phone_number] }.merge(options || {}))
  end
end

# test: assert_not_includes User.new.to_json, "password_digest"
```

## Failure modes
Credential leakage, authorization-only fields exposed, unintended enumeration surfaces.

## Testing
Add negative assertions for representative sensitive fields.

## Review checklist
[ ] sensitive inventory [ ] allowlist [ ] negative tests [ ] consumer review

## Related skills
rails-serialization-globalid-engineering, rails-security-engineering