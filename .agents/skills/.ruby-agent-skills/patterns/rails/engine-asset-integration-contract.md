---
name: engine-asset-integration-contract
description: Engine Asset Integration Contract
family: rails
---
# Engine Asset Integration Contract

## Problem
Engine assets can collide with host assets or bypass the host build/precompile contract.

## Use when
Changing engine assets or frontend integration.

## Do not use when
The engine has no asset/frontend integration.

## Repository inspection
Inspect engine manifests, host asset strategy, build tools, precompile configuration, and artifact ownership.

## Implementation procedure
Integrate through the host's established asset/build contract and keep engine assets namespaced.

## Example

```ruby
# lib/reports_engine/engine.rb
module ReportsEngine
  class Engine < ::Rails::Engine
    isolate_namespace ReportsEngine

    # Assets are namespaced under reports_engine/ and handed to the host's
    # pipeline; the engine never writes into the host's builds directory.
    initializer "reports_engine.assets" do |app|
      app.config.assets.paths << root.join("app/assets/stylesheets") if app.config.respond_to?(:assets)
      app.config.assets.precompile += %w[reports_engine/application.css] if app.config.respond_to?(:assets)
    end
  end
end
```

## Failure modes
Missing assets, fingerprint collisions, duplicate bundles, broken release builds.

## Testing
Test engine asset discovery and release/precompile integration.

## Review checklist
[ ] ownership explicit [ ] host strategy respected [ ] precompile verified

## Related skills
rails-engines-railties-engineering, rails-asset-build-engineering