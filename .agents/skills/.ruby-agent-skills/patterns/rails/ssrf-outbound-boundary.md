---
name: ssrf-outbound-boundary
description: Constrain application-controlled outbound URLs against SSRF, redirect, DNS, credential-forwarding, and resource-exhaustion risks.
family: rails
---

# SSRF Outbound Boundary

## Problem

An application accepts a URL or endpoint influenced by an attacker and then makes a server-side network request.

## Use when

User/provider data can influence HTTP destinations, redirects, callback URLs, import sources, image/document fetches, or webhook targets.

## Do not use when

Outbound destinations are fixed and fully controlled by deployment configuration.

## Repository inspection

Inspect URL parsing, scheme/host allowlists, DNS resolution, redirect handling, IP filtering, HTTP client timeout/size limits, proxy settings, and credential forwarding.

## Implementation procedure

1. Prefer fixed destination allowlists.
2. Validate allowed schemes.
3. Resolve and validate destination host/IP.
4. Reject loopback/private/link-local/metadata destinations when not required.
5. Revalidate redirects.
6. Do not forward ambient credentials to untrusted hosts.
7. Bound connect/read/response size/time.
8. Log safe destination metadata.
9. Test forbidden and allowed destinations.

## Example

```ruby
require "resolv"
require "ipaddr"

class SafeWebhookUrl
  BLOCKED = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
               192.168.0.0/16 ::1/128 fc00::/7 fe80::/10].map { IPAddr.new(_1) }.freeze

  Error = Class.new(StandardError)

  # Returns the URI and the vetted IP; the caller connects to that IP (no second DNS lookup).
  def self.resolve!(raw)
    uri = URI.parse(raw)
    raise Error, "https only" unless uri.is_a?(URI::HTTPS)
    raise Error, "port not allowed" unless uri.port == 443

    addresses = Resolv.getaddresses(uri.host)
    raise Error, "unresolvable host" if addresses.empty?
    ip = IPAddr.new(addresses.first)
    raise Error, "private address" if addresses.any? { |a| BLOCKED.any? { _1.include?(IPAddr.new(a)) } }

    [uri, ip]
  end
end
# Client: open_timeout 3s, read_timeout 5s, no redirects followed, response body capped at 1 MB.
```

## Failure modes

- validating only the input hostname
- redirect bypass
- private-IP access
- DNS rebinding/TOCTOU assumptions
- credential leakage
- unbounded response/resource usage

## Testing

Test loopback/private/link-local destinations, redirects, unsupported schemes, oversized responses, timeout behavior, and approved external destinations.

## Review checklist

- [ ] destination allowlist
- [ ] scheme validation
- [ ] IP/private-range protection
- [ ] redirect validation
- [ ] credential forwarding constrained
- [ ] timeout/size limits
- [ ] abuse tests

## Related skills

- rails-security-engineering
- rails-security
- rails-api-integration
- ruby-gems-io-services
