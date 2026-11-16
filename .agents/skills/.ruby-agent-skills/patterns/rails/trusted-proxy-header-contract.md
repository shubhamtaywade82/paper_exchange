---
name: trusted-proxy-header-contract
description: Normalize forwarded request metadata only from a documented trusted proxy boundary.
family: rails
---
# Trusted Proxy Header Contract

## Problem
Forwarded host, scheme, and client IP headers are attacker-controlled when the deployment does not establish a trusted proxy.

## Use when
Proxy-aware URL generation, client-IP handling, HTTPS enforcement, or security decisions depend on forwarded headers.

## Do not use when
A request originates directly from clients without a trusted proxy contract.

## Repository inspection
Inspect ingress/load balancer topology, trusted proxy configuration, header normalization, and tests for direct versus proxied requests.

## Implementation procedure
Define trusted hops and authoritative headers, then consume only normalized values after the trust boundary.

## Example

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Only the load balancer's addresses may set X-Forwarded-For / -Proto.
  config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + [IPAddr.new("10.20.0.0/16")]
  config.assume_ssl = true # TLS terminates at the load balancer
  config.force_ssl = true
  config.hosts = ["shop.example.com"] # rejects forged Host headers (DNS rebinding, cache poisoning)
end

# request.remote_ip now ignores X-Forwarded-For entries appended by untrusted clients;
# rate limits and audit logs use request.remote_ip, never the raw header.
```

## Failure modes
Host/IP spoofing, insecure redirects, incorrect audit identity, and rate-limit bypass.

## Testing
Test direct clients, trusted proxy requests, malformed headers, and multi-hop behavior relevant to deployment.

## Review checklist
[ ] trusted hops explicit
[ ] raw headers not trusted blindly
[ ] direct path tested
[ ] security consumer verified

## Related skills
rails-rack-middleware-engineering, rails-security-engineering, rails-release-engineering
