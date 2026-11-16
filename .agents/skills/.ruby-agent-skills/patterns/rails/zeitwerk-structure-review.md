---
name: zeitwerk-structure-review
description: Review a Ruby/Rails file and constant tree for Zeitwerk path, namespace, inflection, root, reload, and eager-load correctness.
family: rails
---

# Zeitwerk Structure Review

## Problem
A Ruby/Rails change modifies files or constants managed by Zeitwerk.

## Use when
Use when adding, moving, renaming, or namespacing autoloaded code, or when a loading/eager-loading failure occurs.

## Do not use when
Do not use for ordinary Ruby files outside a Zeitwerk-managed loader.

## Repository inspection
Inspect runtime/version, loader roots, file path, expected constant, namespace ownership, inflections, initializer timing, and eager-load configuration.

## Implementation procedure
1. Identify the loader/root. 2. Derive expected constant from the file path. 3. Check actual definition. 4. Check namespace ownership. 5. Check inflections. 6. Check nested/duplicate roots and ignored paths. 7. Check reloadable versus once-loaded lifecycle. 8. Run bin/rails zeitwerk:check when available. 9. Run affected tests and eager-load verification when relevant.

## Example

```bash
# File path must map to the constant it defines:
#   app/services/billing/invoice_generator.rb  -> Billing::InvoiceGenerator
#   app/models/api_key.rb                       -> ApiKey (or APIKey with an inflection)
# config/initializers/inflections.rb:
#   Rails.autoloaders.main.inflector.inflect("api_key" => "APIKey")

bin/rails zeitwerk:check                          # eager-loads everything and reports mismatches
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'Rails.application.eager_load!; puts "ok"'
```

## Failure modes
- manual require hides mismatch
- nested root changes namespace semantics
- one file defines unrelated top-level constants
- incorrect acronym
- cached reloadable constant
- initializer references reloadable code at wrong lifecycle point

## Testing
Test boot/eager loading and affected behavior. Exercise reload-sensitive behavior when practical.

## Review checklist
- path matches constant
- namespace matches root semantics
- inflection is intentional
- lifecycle is correct
- eager load succeeds
- no unnecessary require workaround

## Related skills
- rails-zeitwerk
- rails-architecture
- rails-release-engineering
- ruby-debugging
- ruby-runtime-compatibility