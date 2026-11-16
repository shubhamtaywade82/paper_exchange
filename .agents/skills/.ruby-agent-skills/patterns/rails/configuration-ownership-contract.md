---
name: configuration-ownership-contract
description: Configuration Ownership Contract
family: rails
---
# Configuration Ownership Contract

## Problem
Framework, application, environment, and secret settings can overlap without a clear owner.

## Use when
Adding or changing a configuration value.

## Do not use when
Behavior with no configuration boundary.

## Repository inspection
Inspect config namespaces, consumers, environments, credentials, and deployment config.

## Implementation procedure
Assign one owner and stable namespace; define type, default, and required status.

## Example

```ruby
# One owner per kind of setting:
#   framework behaviour  -> config/environments/*.rb
#   application settings -> config.x.* (config/application.rb)
#   secrets              -> Rails.application.credentials
#   deployment specifics -> ENV, read in exactly one place
Rails.application.configure do
  config.force_ssl = true                                          # framework
  config.x.uploads.max_bytes = 25.megabytes                        # application
  config.x.stripe.api_key = Rails.application.credentials.dig(:stripe, :api_key) # secret
  config.x.app_host = ENV.fetch("APP_HOST")                        # deployment
end
```

## Failure modes
Duplicated keys, conflicting sources, mutable constants.

## Testing
Test the owner and a real consumer.

## Review checklist
[ ] owner [ ] namespace [ ] default/required [ ] consumer

## Related skills
rails-initialization-configuration-engineering, rails-security-engineering
