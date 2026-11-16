---
name: stimulus-lifecycle-boundary
description: Make Stimulus connect/disconnect behavior safe across Turbo DOM replacement.
family: rails
---
# Stimulus Lifecycle Boundary

## Problem
Turbo reconnection duplicates listeners, timers, observers, or subscriptions.

## Structure
Allocate resources in connect and release them in disconnect; make repeated lifecycle transitions safe.

## Example

```js
// app/javascript/controllers/autorefresh_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: { type: Number, default: 30000 } }

  connect() {
    this.stop() // connect can run again after a Turbo restore/morph: never stack timers
    this.timer = setInterval(() => this.element.reload(), this.intervalValue)
    this.onVisibility = () => (document.hidden ? this.stop() : this.connect())
    document.addEventListener("visibilitychange", this.onVisibility)
  }

  disconnect() {
    this.stop()
    document.removeEventListener("visibilitychange", this.onVisibility)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }
}
```

## Testing
Exercise repeated lifecycle transitions and cleanup.
## Do not use when
The controller owns no resource that requires cleanup.

## Repository inspection
Inspect connect/disconnect hooks, event listeners, timers, observers, subscriptions, and Turbo replacement paths.

## Implementation procedure
Acquire external resources in connect, release them in disconnect, and make repeated cycles safe.

## Failure modes
Duplicate handlers, memory leaks, stale subscriptions, and work continuing after disconnect.

## Testing
Run repeated connect/disconnect cycles and verify cleanup.

## Review checklist
Every acquired resource has a deterministic release path.

## Related skills
rails-hotwire, rails-test-engineering, ruby-concurrency

## Use when

Use this pattern when the described Hotwire interaction is an explicit part of the page contract and its lifecycle needs dedicated guidance.
