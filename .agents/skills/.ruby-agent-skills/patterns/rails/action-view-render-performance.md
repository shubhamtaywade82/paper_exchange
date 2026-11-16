---
name: action-view-render-performance
description: Investigate Action View rendering cost using template, partial, query, allocation, cache, and output evidence.
family: rails
---

# Action View Render Performance

## Problem

Slow views can result from rendering work, data access triggered by rendering, cache misses, compilation, allocation pressure, or oversized output.

## Use when

- diagnosing slow pages;
- optimizing large partial collections;
- reviewing view-driven N+1s;
- changing collection rendering or fragment caching for performance.

## Do not use when

- there is no measured rendering or response bottleneck.

## Repository inspection

Inspect request timings, view instrumentation, query traces, template structure, partial counts, cache behavior, and preload/query conventions.

## Implementation procedure

1. Establish baseline latency, query, and allocation evidence.
2. Separate controller/data-preparation cost from view-render cost.
3. Identify repeated partial or helper work.
4. Choose collection/object rendering or preload changes that own the bottleneck.
5. Add cache only with explicit correctness identity.
6. Measure again.
7. Record workload-specific tradeoffs.

## Example

```erb
<%# app/views/orders/index.html.erb
    Measured first (rack-mini-profiler showed 1 query per row and 380 ms in
    _order partials). Controller now preloads: current_account.orders.includes(:customer).
    Collection rendering renders the partial once per row without per-row
    lookup overhead, and cached: true reads fragments in one multi-get. %>
<ul>
  <%= render partial: "orders/order", collection: @orders, as: :order, cached: true %>
</ul>
```

## Failure modes

- optimizing without measurement;
- hiding N+1 behind caching;
- globally preloading unrelated data;
- increasing memory or compilation cost for marginal gain;
- caching authorization-sensitive output too broadly.

## Testing

Use deterministic request/render tests and stable performance measurements where repository thresholds exist.

## Review checklist

- [ ] baseline captured
- [ ] bottleneck isolated
- [ ] query/render distinction explicit
- [ ] cache correctness reviewed
- [ ] post-change evidence captured

## Related skills

- skills/rails-action-view/SKILL.md
- skills/rails-performance/SKILL.md
- skills/ruby-performance/SKILL.md
- skills/rails-caching/SKILL.md
