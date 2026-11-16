---
name: active-storage-processing
description: Bound Active Storage analysis, variants, previews, and transformation workloads across dependencies, jobs, CPU, memory, and failure semantics.
family: rails
---

# Active Storage Processing

## Problem

File analysis and transformations can become expensive asynchronous workloads with external binary dependencies and unbounded resource consumption.

## Use when

- adding analyzers, variants, previews, or media transformations;
- diagnosing processing latency or worker exhaustion.

## Do not use when

- no file processing occurs.

## Repository inspection

Inspect Active Job queues, processing dependencies, transformation definitions, concurrency, memory/CPU limits, retry behavior, and generated variants.

## Implementation procedure

1. Define required derived representations.
2. Prefer named bounded transformations.
3. Verify system dependencies.
4. Choose processing queue/concurrency.
5. Bound source/output sizes and work.
6. Classify failures.
7. Observe processing latency/failures.
8. Test malformed/unsupported inputs.

## Example

```ruby
class Photo < ApplicationRecord
  has_one_attached :image do |attachable|
    # Preprocessed on upload in a background job, not lazily on first view.
    attachable.variant :card, resize_to_limit: [800, 800], format: :webp, preprocessed: true
  end
end

# config/environments/production.rb
Rails.application.configure do
  config.active_storage.variant_processor = :vips # libvips must be installed in the image
  config.active_storage.queues.analysis = :media
  config.active_storage.queues.transform = :media   # isolated, concurrency-limited queue
end
```

## Failure modes

- user-controlled transformation parameters;
- oversized media exhausting workers;
- missing production binaries;
- infinite retry of malformed files;
- processing sensitive files without access controls.

## Testing

Test valid, malformed, unsupported, oversized, and retry/failure cases using isolated storage.

## Review checklist

- [ ] bounded transform
- [ ] dependency available
- [ ] queue/capacity
- [ ] retry classification
- [ ] malformed input
- [ ] security boundary

## Related skills

rails-active-storage, rails-active-job, rails-performance, ruby-performance, rails-reliability-engineering
