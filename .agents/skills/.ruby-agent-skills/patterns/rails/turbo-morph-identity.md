---
name: turbo-morph-identity
description: Preserve stable DOM identity and client state when Turbo morphing or refresh is used.
family: rails
---
# Turbo Morph Identity

## Problem
Morphing unexpectedly resets inputs, dialogs, or Stimulus state.

## Structure
Define stable IDs and explicit boundaries for state that must survive refresh.

## Example

```erb
<%# layouts/application.html.erb %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>

<%# Stable ids let morphing match elements instead of replacing them. %>
<ul id="tasks">
  <% @tasks.each do |task| %>
    <li id="<%= dom_id(task) %>"><%= task.title %></li>
  <% end %>
</ul>

<%# Client state that must survive a refresh is excluded from morphing. %>
<div id="draft-comment" data-turbo-permanent>
  <textarea name="draft"></textarea>
</div>
```

## Testing
Assert preservation of focused/input/client state that the feature contract requires.

## Do not use when
A targeted Frame or Stream update is sufficient and morphing adds unnecessary complexity.

## Repository inspection
Inspect stable DOM IDs, form/input state, Stimulus controllers, and Turbo version support.

## Implementation procedure
Identify state that must survive, preserve IDs, define morph boundaries, and verify controller lifecycle behavior.

## Failure modes
Lost focus, reset inputs, duplicated controllers, and unstable target identity.

## Testing
Exercise refresh/morph with representative client state.

## Review checklist
State ownership and DOM identity are explicit.

## Related skills
rails-hotwire, rails-action-view, rails-test-engineering

## Use when

Use this pattern when the described Hotwire interaction is an explicit part of the page contract and its lifecycle needs dedicated guidance.
