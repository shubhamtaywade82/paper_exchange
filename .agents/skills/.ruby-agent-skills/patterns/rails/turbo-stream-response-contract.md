---
name: turbo-stream-response-contract
description: Define deterministic Turbo Stream response actions and target identities.
family: rails
---
# Turbo Stream Response Contract

## Problem
Stream responses mutate unintended DOM or produce inconsistent UI state.

## Structure
Document action, target, ordering, rendered partial, and fallback response semantics.

## Example

```erb
<%# comments/create.turbo_stream.erb — ordered, targeted, documented. %>
<%# 1. Append the new comment to the list (target must exist on posts/show). %>
<%= turbo_stream.append "comments", partial: "comments/comment", locals: { comment: @comment } %>
<%# 2. Replace the form with a fresh one (same id as the original form). %>
<%= turbo_stream.replace dom_id(@post, :new_comment), partial: "comments/form", locals: { post: @post, comment: Comment.new } %>
<%# 3. Update the counter. %>
<%= turbo_stream.update dom_id(@post, :comments_count), @post.comments.size %>
<%# Non-Turbo clients get the HTML redirect from the controller instead. %>
```

## Testing
Verify create/update/delete paths and invalid-form behavior.

## Do not use when
A normal HTML response already expresses the required interaction.

## Repository inspection
Inspect stream templates, target IDs, controller formats, partials, and fallback responses.

## Implementation procedure
Define action and target, render the smallest partial, preserve status semantics, and keep target identity stable.

## Failure modes
Wrong target, malformed stream, duplicate mutation, and missing fallback behavior.

## Testing
Test each stream action and invalid-form path.

## Review checklist
Action, target, partial, status, and fallback are deterministic.

## Related skills
rails-hotwire, rails-action-controller, rails-action-view

## Use when

Use this pattern when the described Hotwire interaction is an explicit part of the page contract and its lifecycle needs dedicated guidance.
