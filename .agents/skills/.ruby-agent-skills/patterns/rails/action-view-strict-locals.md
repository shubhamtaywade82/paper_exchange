---
name: action-view-strict-locals
description: Use strict Action View local signatures to make reusable templates explicit and reduce accidental rendering variants.
family: rails
---

# Action View Strict Locals

## Problem

Reusable partials accept arbitrary local combinations, making missing inputs and caller contracts difficult to reason about.

## Use when

- a partial has stable callers;
- missing or unknown locals should fail immediately;
- local combinations are causing compilation or memory overhead.

## Do not use when

- the partial is highly dynamic by design;
- the supported Rails version does not provide the feature.

## Repository inspection

Resolve Rails/Action View version and inspect existing locals signature usage.

## Implementation procedure

1. Enumerate required, default, and optional locals.
2. Add the smallest supported strict signature.
3. Update callers to match.
4. Test missing, unknown, default, and valid local cases.
5. Measure compilation impact only when material.

## Example

```erb
<%# app/views/shared/_avatar.html.erb %>
<%# locals: (user:, size: 32, link: true) -%>
<%# Required and optional locals are declared; `render "shared/avatar", usr: u`
    raises ActionView::Template::Error instead of rendering a broken avatar. %>
<% image = image_tag(user.avatar_url(size: size), alt: user.name, width: size, height: size) %>
<%= link ? link_to(image, user) : image %>
```

## Failure modes

- adopting syntax unsupported by the repository Rails version;
- making optional locals accidentally required;
- changing behavior for hidden callers;
- adding strict locals to every partial without a stable interface.

## Testing

Test valid render, missing required local, unknown local, and default local behavior.

## Review checklist

- [ ] version verified
- [ ] local interface documented
- [ ] callers audited
- [ ] failure cases tested
- [ ] adoption justified

## Related skills

- skills/rails-action-view/SKILL.md
- skills/ruby-runtime-compatibility/SKILL.md
- skills/rails-test-engineering/SKILL.md
