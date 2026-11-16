---
name: active-support-loading-boundary
description: Choose and verify the smallest Active Support loading/import boundary for Rails applications and reusable Ruby libraries.
family: rails
---

# Active Support Loading Boundary

## Problem

Active Support can be loaded broadly or selectively, and a library can accidentally rely on Rails-wide extensions that are unavailable in standalone use.

## Use when

- adding Active Support to a gem/library;
- changing require/import boundaries;
- using core extensions outside a Rails application.

## Do not use when

- the task changes behavior unrelated to loading or dependency ownership.

## Repository inspection

Inspect gemspec/Gemfile dependencies, Rails boot files, existing require statements, supported Ruby/Rails versions, and tests that run without full Rails boot.

## Implementation procedure

1. Identify the exact Active Support API used.
2. Determine whether the application already loads it.
3. For reusable code, declare the required dependency explicitly.
4. Prefer targeted loading over all-of-Active-Support loading where footprint matters.
5. Test the code in the repository's supported boot modes.
6. Document standalone requirements when applicable.

## Example

```ruby
# lib/money_parser.rb in a standalone gem: load only what is used, instead of
# `require "active_support/all"` and relying on the whole core_ext set.
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/filters"

module MoneyParser
  def self.cents(input)
    return nil if input.blank?

    (BigDecimal(input.squish.delete(",$")) * 100).to_i
  end
end
```

## Failure modes

- works only because Rails already loaded an extension;
- active_support/all added unnecessarily to a library;
- hidden dependency not present in standalone tests;
- version-specific require path assumed.

## Testing

Test focused require/boot behavior and the actual consumer API.

## Review checklist

- [ ] dependency explicit
- [ ] loading scope justified
- [ ] standalone behavior considered
- [ ] version compatibility tested

## Related skills

- skills/rails-active-support/SKILL.md
- skills/ruby-runtime-compatibility/SKILL.md
- skills/rails-zeitwerk/SKILL.md
