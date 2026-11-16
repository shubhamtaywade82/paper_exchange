---
name: turbo-drive-navigation-contract
description: Define page navigation behavior, persistent shell state, and Turbo lifecycle cleanup.
family: rails
---
# Turbo Drive Navigation Contract

## Problem
Turbo navigation changes page lifecycle and can expose duplicate listeners or stale client state.

## Use when
A page or layout relies on navigation events, persistent DOM, page-specific scripts, or browser history.

## Structure
Keep persistent shell state separate from page state and initialize and cleanup behavior explicitly.

## Example

```js
// app/javascript/application.js
import "@hotwired/turbo-rails"
import "controllers"

// Page-level setup belongs in Stimulus connect/disconnect, which run on every visit.
// Document-level listeners are registered once, here, because Turbo keeps the document.
document.addEventListener("turbo:before-cache", () => {
  // Remove transient UI so the cached snapshot does not show it on back navigation.
  document.querySelectorAll("[data-flash]").forEach((el) => el.remove())
})

// Markup:
// <%# Persistent shell: survives navigation without re-initializing. %>
// <audio id="player" data-turbo-permanent src="<%= @episode&.audio_url %>"></audio>
// <meta name="turbo-cache-control" content="no-cache"> <%# on pages with private, fast-changing data %>
```

## Testing
Verify visit, back/forward, redirect, and revisit behavior where material.

## Do not use when
The page does not depend on Turbo lifecycle behavior.

## Repository inspection
Inspect layouts, Turbo setup, existing lifecycle listeners, Stimulus controllers, and browser/system tests.

## Implementation procedure
Identify persistent versus page state, use documented lifecycle hooks, make initialization idempotent, and clean up page-specific resources.

## Failure modes
Duplicate listeners, stale page state, broken back navigation, and state leaking between visits.

## Testing
Test navigation, revisit, and back/forward behavior where lifecycle state matters.

## Review checklist
Persistent state is intentional, cleanup is deterministic, and browser history remains correct.

## Related skills
rails-hotwire, rails-action-view, rails-test-engineering
