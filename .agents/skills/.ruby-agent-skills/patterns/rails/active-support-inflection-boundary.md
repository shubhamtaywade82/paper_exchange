---
name: active-support-inflection-boundary
description: Use Active Support inflection and constantization safely at naming and framework boundaries.
family: rails
---

# Active Support Inflection Boundary

## Problem

Inflection and dynamic constantization convert strings into framework concepts and can become both compatibility and security boundaries.

## Use when

- adding custom inflections;
- using constantize/safe_constantize;
- mapping external names to Ruby constants.

## Do not use when

- normal static constant references are sufficient.

## Repository inspection

Inspect inflections.rb, Zeitwerk conventions, routing/serialization names, dynamic input sources, and tests.

## Implementation procedure

1. Prefer static mappings for external/user-controlled values.
2. Scope inflection changes narrowly.
3. Use explicit allowlists before dynamic constantization.
4. Keep autoloading concerns with rails-zeitwerk.
5. Test irregular names and missing constants.
6. Review authorization around dynamic type selection.

## Example

```ruby
# config/initializers/inflections.rb
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "API"
  inflect.irregular "criterion", "criteria"
end

# Never constantize external input directly; map it through an allowlist.
EXPORTERS = { "orders" => OrderExporter, "invoices" => InvoiceExporter }.freeze
exporter_class = EXPORTERS.fetch(params[:type]) { raise ActionController::BadRequest }
# not: params[:type].classify.constantize
```

## Failure modes

- arbitrary user string constantized;
- global inflection change breaks unrelated resources;
- safe_constantize used to silently hide invalid input;
- autoloading failure misdiagnosed as inflection behavior.

## Testing

Test irregular inflections, missing constants, allowlist rejection, and actual framework naming consumers.

## Review checklist

- [ ] source of string is trusted/validated
- [ ] allowlist considered
- [ ] inflection change bounded
- [ ] Zeitwerk boundary respected
- [ ] security tests exist

## Related skills

- skills/rails-active-support/SKILL.md
- skills/rails-zeitwerk/SKILL.md
- skills/rails-security-engineering/SKILL.md
