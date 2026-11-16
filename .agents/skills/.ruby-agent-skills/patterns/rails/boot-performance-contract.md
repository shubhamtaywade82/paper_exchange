---
name: boot-performance-contract
description: Boot Performance Contract
family: rails
---
# Boot Performance Contract

## Problem
Slow initialization increases deployment and restart time.

## Use when
An initializer adds measurable startup work.

## Do not use when
Micro-optimization without evidence.

## Repository inspection
Inspect boot timings, eager loading, dependency calls, and restart frequency.

## Implementation procedure
Measure the slow boundary, remove unnecessary work, and defer optional work when valid.

## Example

```bash
# Measure boot before changing it: where do the seconds go?
time bin/rails runner 'nil'
RUBYOPT="-r./config/boot" ruby -e 'require "benchmark"; puts Benchmark.realtime { require_relative "config/environment" }'

# Bootsnap caches load paths and compiled Ruby; eager loading happens once in
# production, not in each command.
grep -q "bootsnap/setup" config/boot.rb || echo "bootsnap not enabled"
```

## Failure modes
Premature optimization and semantic shortcuts.

## Testing
Use boot timing evidence and regression checks.

## Review checklist
[ ] baseline [ ] cost localized [ ] semantics preserved

## Related skills
rails-initialization-configuration-engineering, rails-production-runtime, rails-performance
