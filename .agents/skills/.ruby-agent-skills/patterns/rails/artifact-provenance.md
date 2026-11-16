---
name: artifact-provenance
description: Preserve source, dependency, build, and artifact identity across release promotion.
family: rails
---

# Artifact Provenance

## Problem
Rebuilding per environment makes it difficult to prove what was actually tested and deployed.

## Use when
- designing build/promotion pipelines;
- reviewing release evidence;
- debugging environment-specific release drift.

## Do not use when
- the repository deliberately uses a different immutable artifact model and already proves identity another way.

## Repository inspection
Inspect CI build jobs, image/package identifiers, lockfiles, registries, tags/digests, deployment manifests, and release metadata.

## Implementation procedure
1. Capture source revision. 2. Capture dependency lock/build inputs. 3. Produce an immutable artifact identity. 4. Promote the same artifact. 5. Record target environment and deployment result. 6. Make provenance queryable.

## Example

```bash
# Build once, record identity, promote the same image to every environment.
sha=$(git rev-parse HEAD)
docker buildx build --push --tag "registry.example.test/shop:$sha" --metadata-file build.json .
digest=$(jq -r '."containerimage.digest"' build.json)
printf '{"git_sha":"%s","image_digest":"%s"}\n' "$sha" "$digest" > provenance.json

# Staging and production deploy that exact tag; nothing is rebuilt per environment.
kamal deploy --version "$sha" --skip-push --destination staging
kamal deploy --version "$sha" --skip-push --destination production
```

## Failure modes
- per-environment rebuilds;
- mutable image tags without digest tracking;
- missing source-to-artifact link;
- secrets embedded in provenance.

## Testing
Verify that a promoted artifact retains its source identity and that release records reference the same immutable artifact.

## Review checklist
- [ ] source revision; - [ ] dependency identity; - [ ] immutable artifact; - [ ] promotion identity; - [ ] no secrets.

## Related skills
rails-release-engineering, rails-production-runtime, rails-security-engineering
