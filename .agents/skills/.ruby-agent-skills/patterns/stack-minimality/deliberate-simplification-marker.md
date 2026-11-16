---
name: deliberate-simplification-marker
description: Deliberate Simplification Marker
family: stack-minimality
---
# Deliberate Simplification Marker

## Problem
A simple solution can have a known ceiling that should remain visible.

## Use when
Choosing a deliberately bounded algorithm, lock, cache, batch size, or state model.

## Do not use when
There is no meaningful tradeoff or the shortcut would remove a required guarantee.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Record a stack-minimality marker with the ceiling and a concrete trigger at the decision site.

## Example

```ruby
class ExchangeRates
  # stack-minimality: rates cached per process for 10 minutes; revisit when more
  # than one process needs identical rates at the same instant or the provider
  # rate-limits us.
  def self.rate(from, to)
    @cache ||= {}
    entry = @cache[[from, to]]
    return entry[:rate] if entry && entry[:at] > Time.now - 600

    rate = RatesProvider.fetch(from, to)
    @cache[[from, to]] = { rate: rate, at: Time.now }
    rate
  end
end
```

## Failure modes
TODO-later comments without triggers and debt markers used to excuse unsafe behavior.

## Testing
The marker itself needs no test; the underlying behavior does.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
stack-minimality, stack-minimality-debt, ruby-clean-code
