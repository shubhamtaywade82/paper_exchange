---
name: external-api-client
description: Use when integrating a remote HTTP/API boundary that should be isolated from domain code and made testable.
family: ruby-design
---

# External API Client

## Problem

Remote APIs introduce transport, authentication, serialization, timeout, retry, and response-contract concerns that should not leak through the rest of the application.

## Use when

- a feature consumes a remote HTTP API
- raw HTTP calls appear in controllers/models
- an API response needs normalization before domain use
- external failure behavior must be tested independently

## Do not use when

- the repository already has a stable client for the same service
- the operation is a one-off script with no reusable boundary
- introducing a wrapper would only rename one existing method

## Repository inspection

Inspect existing HTTP libraries, client classes, authentication configuration, timeout conventions, error types, test doubles, and observability before creating a new boundary.

## Implementation procedure

1. define the domain-facing client API
2. isolate transport behind the client
3. centralize base URL/authentication/headers
4. set explicit connect/read timeouts where the library supports them
5. validate status and response shape
6. normalize external data into an application-facing structure
7. map remote failures to explicit local errors/results
8. make the transport replaceable in tests
9. avoid logging secrets or full sensitive payloads

## Example

```ruby
require "json"
require "net/http"

# Transport, auth, timeouts, and payload shape stay inside the client; the
# application sees a small value and one error type.
class GeocodingClient
  Error = Class.new(StandardError)
  Location = Data.define(:lat, :lng)

  def initialize(api_key:, base_uri: URI("https://geo.example.test"), timeout: 2)
    @api_key = api_key
    @base_uri = base_uri
    @timeout = timeout
  end

  def locate(address)
    uri = @base_uri.dup
    uri.path = "/v1/geocode"
    uri.query = URI.encode_www_form(q: address)
    request = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{@api_key}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: @timeout, read_timeout: @timeout) do |http|
      http.request(request)
    end
    raise Error, "geocoding failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    Location.new(lat: body.fetch("lat"), lng: body.fetch("lng"))
  rescue JSON::ParserError, KeyError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "geocoding failed: #{e.class}"
  end
end
```

## Failure modes

- raw HTTP calls scattered through business code
- no timeout
- accepting a successful HTTP status without validating the body
- leaking provider-specific response objects everywhere
- broad rescue that hides network failures
- retries without an idempotency/retry policy
- credentials embedded in source

## Testing

Test successful response mapping, non-success responses, malformed payloads, timeout behavior where practical, and the domain-facing contract. Use a fake transport rather than a real network call for unit tests.

## Review checklist

- [ ] client API is small and domain-oriented
- [ ] transport is isolated
- [ ] timeout/error behavior is explicit
- [ ] response validation exists
- [ ] secrets are not logged
- [ ] network calls are replaceable in tests
- [ ] provider-specific details do not leak unnecessarily

## Related skills

- ruby-gems-io-services
- ruby-api-design
- ruby-debugging
- ruby-tdd-refactoring
