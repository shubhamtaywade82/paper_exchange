---
name: configuration-precedence-contract
description: Configuration Precedence Contract
family: rails
---
# Configuration Precedence Contract

## Problem
Multiple configuration sources can silently override one another.

## Use when
A setting has multiple possible sources.

## Do not use when
A single immutable source owns it.

## Repository inspection
Inspect every assignment/read and deployment-provided value.

## Implementation procedure
Document actual precedence and normalize values at the boundary.

## Example

```ruby
# Precedence is explicit and in one place: ENV overrides credentials, which
# override the checked-in default. Nothing else reads ENV for this setting.
module Settings
  def self.smtp_host
    ENV["SMTP_HOST"].presence ||
      Rails.application.credentials.dig(:smtp, :host) ||
      "localhost"
  end
end
```

## Failure modes
Unexpected overrides and environment drift.

## Testing
Test source combinations and missing/invalid values.

## Review checklist
[ ] sources mapped [ ] precedence explicit [ ] invalid values tested

## Related skills
rails-initialization-configuration-engineering, rails-production-runtime
