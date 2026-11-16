---
name: action-view-layout-contract
description: Define layout selection and shared presentation responsibilities without hiding business behavior in Action View layouts.
family: rails
---

# Action View Layout Contract

## Problem

Layouts are shared presentation infrastructure and can accidentally become business workflows or authorization boundaries.

## Use when

- adding multiple layouts;
- changing layout selection;
- introducing content_for contracts;
- debugging shared navigation or metadata.

## Do not use when

- only one static layout is edited and selection semantics are unchanged.

## Repository inspection

Inspect ApplicationController, layout files, controller layout declarations, content_for usage, authentication/navigation helpers, variants, and tests.

## Implementation procedure

1. Define layout-selection criteria.
2. Keep selection deterministic and independent of untrusted input.
3. Keep layout responsibilities presentation-only.
4. Define content slots explicitly.
5. Preserve authentication and tenant state passed into shared presentation.
6. Test representative controller/layout combinations.

## Example

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title><%= content_for?(:title) ? yield(:title) : "Acme" %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application" %>
    <%= javascript_importmap_tags %>
  </head>
  <body>
    <%= render "layouts/navigation", user: Current.user %>
    <main id="main"><%= yield %></main>
  </body>
</html>
```

## Failure modes

- dynamic layout names from user input;
- authorization hidden in navigation rendering;
- data-loading loops in layouts;
- missing content_for contracts;
- tenant/private information rendered in shared layouts.

## Testing

Test layout selection and important content-slot behavior for representative request contexts.

## Review checklist

- [ ] selection explicit
- [ ] no user-controlled layout path
- [ ] presentation-only responsibility
- [ ] content slots explicit
- [ ] tests cover contexts

## Related skills

- skills/rails-action-view/SKILL.md
- skills/rails-action-controller/SKILL.md
- skills/rails-security-engineering/SKILL.md
