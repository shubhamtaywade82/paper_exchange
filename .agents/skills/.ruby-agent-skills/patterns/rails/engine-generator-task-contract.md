---
name: engine-generator-task-contract
description: Engine Generator and Task Contract
family: rails
---
# Engine Generator and Task Contract

## Problem
Generators, tasks, and migrations can unintentionally mutate hosts or collide with other extensions.

## Use when
Changing engine generators, tasks, install hooks, or migrations.

## Do not use when
No generator/task/migration boundary is affected.

## Repository inspection
Inspect generated paths, task names, prerequisites, migration ownership, and install workflow.

## Implementation procedure
Namespace tasks, make generated changes explicit, and keep migrations/reversibility compatible with host integration.

## Example

```ruby
# lib/generators/reports_engine/install/install_generator.rb
module ReportsEngine
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    # Idempotent and namespaced: re-running does not duplicate routes or
    # overwrite a host-edited initializer.
    def copy_initializer
      template "reports_engine.rb", "config/initializers/reports_engine.rb", skip: true
    end

    def mount_engine
      route 'mount ReportsEngine::Engine, at: "/reports"' unless File.read("config/routes.rb").include?("ReportsEngine::Engine")
    end

    def copy_migrations
      rake "reports_engine:install:migrations"
    end
  end
end
```

## Failure modes
Task collisions, irreversible changes, migration conflicts, hidden host mutation.

## Testing
Test generator output, task execution, and migration behavior where applicable.

## Review checklist
[ ] namespace [ ] side effects explicit [ ] migration ownership [ ] reversible

## Related skills
rails-engines-railties-engineering, rails-generators, rails-database-engineering