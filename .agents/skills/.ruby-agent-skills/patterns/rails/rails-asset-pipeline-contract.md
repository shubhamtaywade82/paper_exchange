---
name: rails-asset-pipeline-contract
description: Define the Rails static asset resolution, fingerprinting, and delivery boundary.
family: rails
---
# Rails Asset Pipeline Contract

## Problem

Rails can serve stale, missing, or incorrectly fingerprinted assets when source, manifest, precompile, and delivery contracts diverge.

## Use when
Changing static asset delivery, fingerprinting, manifests, or the Rails asset pipeline.

## Do not use when
Only changing application JavaScript/CSS source with no asset pipeline behavior change.

## Repository inspection
Inspect Rails version, Propshaft/Sprockets, manifests, precompile tasks, public assets, deployment scripts, and cache headers.

## Implementation procedure
Define source-to-artifact ownership, fingerprinting, precompile behavior, and delivery/cache semantics before changing configuration.

## Example

```bash
# Propshaft: every asset referenced with a helper gets a digest; the manifest maps logical -> digested.
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
test -f public/assets/.manifest.json || { echo "manifest missing" >&2; exit 1; }
grep -q '"application.css"' public/assets/.manifest.json

# Views use helpers so paths resolve through the manifest:
#   <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
#   <%= image_tag "logo.svg" %>        (not <img src="/assets/logo.svg">)
# Production: config.public_file_server.headers = { "cache-control" => "public, max-age=31536000, immutable" }
```

## Failure modes
Missing manifests, stale assets, digest mismatch, deployment artifact drift, and unsafe cache reuse.

## Testing
Run clean asset precompile and verify expected fingerprinted outputs.

## Review checklist
[ ] pipeline identified
[ ] artifact contract explicit
[ ] digest/cache behavior verified
[ ] deployment path tested

## Related skills
rails-asset-build-engineering, rails-release-engineering, rails-production-runtime, rails-caching
