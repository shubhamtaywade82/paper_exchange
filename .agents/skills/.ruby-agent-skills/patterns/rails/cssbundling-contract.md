---
name: cssbundling-contract
description: Define a reproducible Rails CSS compilation and delivery boundary.
family: rails
---
# CSS Bundling Contract

## Problem

CSS can appear correct in a watcher while the release build produces missing or stale compiled output.

## Use when
CSS requires Sass/PostCSS/Tailwind or another build-time transformation.

## Do not use when
Plain CSS and the existing asset pipeline already satisfy the application's needs.

## Repository inspection
Inspect CSS entrypoints, build scripts, package manager, lockfile, browser targets, Rails asset pipeline, and production artifact path.

## Implementation procedure
Define source/output ownership, build command, dependency versions, and integration with Rails precompile/deploy.

## Example

```bash
# The release path, not the watcher, is what CI proves:
yarn install --immutable
yarn build:css                      # package.json: "build:css": "tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify"
test -s app/assets/builds/application.css
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile   # cssbundling-rails runs build:css as part of this
```

## Failure modes
Watcher-only success, stale compiled CSS, incompatible browser targets, missing imports, and artifact mismatch.

## Testing
Run a clean production-like CSS build and verify the resulting asset is consumed by the deployed Rails path.

## Review checklist
[ ] source/output boundary explicit
[ ] build deterministic
[ ] Rails consumes compiled output
[ ] clean build passes

## Related skills
rails-asset-build-engineering, rails-action-view, rails-release-engineering
