---
name: credentials-environment-selection
description: Credentials Environment Selection Contract
family: rails
---
# Credentials Environment Selection Contract

## Problem
Ambiguous environment-specific credential selection can make the wrong secret available to the wrong runtime.

## Use when
An application uses per-environment credentials or custom credential paths.

## Do not use when
There is one deliberately shared credential store with a documented policy.

## Repository inspection
Inspect config.credentials.content_path, config.credentials.key_path, environment files, and deployment commands.

## Implementation procedure
Make environment selection explicit and test the expected credential/key pair in each supported environment.

## Example

```ruby
# config/credentials/production.yml.enc is decrypted with
# config/credentials/production.key (or RAILS_MASTER_KEY) only when
# RAILS_ENV=production; staging has its own file and key.
Rails.application.configure do
  config.credentials.content_path = Rails.root.join("config/credentials/#{Rails.env}.yml.enc")
  config.credentials.key_path = Rails.root.join("config/credentials/#{Rails.env}.key")
end

Rails.application.credentials.dig(:stripe, :secret_key) # nil outside production, never the wrong env's key
```

## Failure modes
Production reads development credentials, missing keys, or accidental fallback to shared credentials.

## Testing
Exercise credential loading under each supported Rails environment.

## Review checklist
[ ] path explicit [ ] key explicit [ ] environment test [ ] fallback understood

## Related skills
rails-encryption-credentials-engineering, rails-initialization-configuration-engineering