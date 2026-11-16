---
name: middleware-security-boundary
description: Use middleware for transport/infrastructure security controls without moving resource authorization into the stack.
family: rails
---
# Middleware Security Boundary

## Problem
Security checks can be duplicated or misplaced when generic middleware starts deciding business permissions.

## Use when
Trusted-host, HTTPS/security headers, proxy normalization, CORS, request-size, or infrastructure-level controls are being changed.

## Do not use when
The decision requires authenticated resource ownership, tenant membership, or business policy.

## Repository inspection
Inspect trust boundaries, proxy configuration, authentication/authorization ownership, security headers, and deployment topology.

## Implementation procedure
Define the untrusted input, authoritative infrastructure boundary, failure response, and interaction with controller authorization.

## Example

```ruby
# Middleware: coarse, request-generic checks only.
Rails.application.config.middleware.insert_before 0, Rack::Attack
Rails.application.config.hosts = ["shop.example.com", /.*\.shop\.example\.com/]

# Business permission stays at the resource boundary, where the record is known.
class InvoicesController < ApplicationController
  def show
    @invoice = Current.account.invoices.find(params[:id]) # tenant scope
    authorize @invoice                                    # policy decision
  end
end

# Wrong: a middleware that parses /invoices/:id and queries ownership itself —
# it duplicates the policy and misses every non-HTTP entry point.
```

## Failure modes
Header spoofing, CORS drift, proxy trust abuse, authorization bypass, and inconsistent security policy.

## Testing
Test trusted/untrusted proxy inputs, required headers, rejection paths, and controller authorization separately.

## Review checklist
[ ] trust boundary explicit
[ ] proxy assumptions verified
[ ] authz remains at resource boundary
[ ] abuse regression covered

## Related skills
rails-rack-middleware-engineering, rails-security-engineering, rails-authorization
