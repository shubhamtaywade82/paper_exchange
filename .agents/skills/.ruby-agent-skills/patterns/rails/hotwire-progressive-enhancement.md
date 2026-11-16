---
name: hotwire-progressive-enhancement
description: Treat Hotwire as enhancement over a valid server-rendered HTML contract.
family: rails
---
# Hotwire Progressive Enhancement

## Problem
The application only works when Turbo or Stimulus executes successfully.

## Structure
Preserve meaningful HTML forms, links, statuses, errors, and server authorization independently of client enhancements.

## Example

```erb
<%# A plain form and link: work without JavaScript, enhanced by Turbo when present. %>
<%= turbo_frame_tag dom_id(@comment, :edit) do %>
  <%= form_with model: @comment do |form| %>
    <% if @comment.errors.any? %>
      <div role="alert"><%= @comment.errors.full_messages.to_sentence %></div>
    <% end %>
    <%= form.label :body %>
    <%= form.text_area :body, required: true %>
    <%= form.submit "Save" %>
  <% end %>
  <%= link_to "Cancel", @comment.post %>
<% end %>
<%# Controller: invalid -> render :edit, status: :unprocessable_entity (works for both HTML and Turbo). %>
```

## Testing
Verify direct HTTP/HTML behavior for critical workflows in addition to enhanced behavior.
## Do not use when
A feature is explicitly non-functional without JavaScript and that limitation is intentional.

## Repository inspection
Inspect server-rendered HTML, forms, links, fallback responses, and accessibility expectations.

## Implementation procedure
Build the server HTML contract first, then add Turbo and Stimulus enhancement without moving authorization into the client.

## Failure modes
JavaScript-only workflows, broken direct requests, inaccessible fallbacks, and hidden server assumptions.

## Testing
Verify direct HTTP and HTML behavior for critical workflows.

## Review checklist
Critical workflows remain meaningful without enhancement where required.

## Related skills
rails-hotwire, rails-action-controller, rails-action-view, rails-security

## Use when

Use this pattern when the Hotwire interaction relies on the named security or progressive-enhancement boundary.
