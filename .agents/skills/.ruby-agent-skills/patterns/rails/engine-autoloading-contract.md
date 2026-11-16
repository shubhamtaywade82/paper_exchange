---
name: engine-autoloading-contract
description: Engine Autoloading Contract
family: rails
---
# Engine Autoloading Contract

## Problem
Engine file layout can violate Zeitwerk expectations or hide load-order bugs behind manual requires.

## Use when
Changing engine app/lib paths, namespaces, or requires.

## Do not use when
No autoloading or file-layout change.

## Repository inspection
Inspect engine autoload roots, namespace mapping, eager loading, and current Zeitwerk errors.

## Implementation procedure
Align paths and constants with the loader contract before adding explicit requires.

## Example

```ruby
# engines/billing/app/models/billing/invoice.rb      -> Billing::Invoice
# engines/billing/app/services/billing/charge.rb     -> Billing::Charge
# engines/billing/lib/billing/engine.rb              -> Billing::Engine (loaded once)
module Billing
  class Engine < ::Rails::Engine
    isolate_namespace Billing
  end
end
# No require_dependency / require for app/ files; verify with:
#   bin/rails zeitwerk:check
```

## Failure modes
Zeitwerk errors, stale constants, production eager-load failures.

## Testing
Run zeitwerk:check/eager-load verification and engine boot tests.

## Review checklist
[ ] path/constant alignment [ ] eager-load checked [ ] no masking require

## Related skills
rails-engines-railties-engineering, rails-zeitwerk