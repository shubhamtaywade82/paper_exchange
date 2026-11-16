---
name: hotwire-csrf-security
description: Preserve Rails CSRF and server-side security semantics in Turbo-driven interactions.
family: rails
---
# Hotwire CSRF Security

## Problem
Client-side requests or custom JavaScript accidentally bypass Rails CSRF expectations.

## Structure
Classify browser authentication first and preserve the repository CSRF contract. Never weaken protection to make a Turbo interaction work.

## Example

```ruby
# app/views/layouts/application.html.erb includes <%= csrf_meta_tags %>;
# Turbo form submissions send the token automatically.

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception # unchanged: never disabled to make fetch work
end

# app/javascript/controllers/archive_controller.js (Stimulus) sends the token explicitly:
#   const token = document.querySelector("meta[name='csrf-token']").content
#   fetch(this.urlValue, { method: "PATCH", headers: { "X-CSRF-Token": token } })

# test/integration/archive_csrf_test.rb
require "test_helper"

class ArchiveCsrfTest < ActionDispatch::IntegrationTest
  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }

  test "rejects a patch without a CSRF token" do
    sign_in users(:owner)
    patch archive_project_path(projects(:alpha))
    assert_response :unprocessable_entity
  end
end
```

## Testing
Cover non-GET requests, redirects, and rejection behavior.
## Do not use when
The interaction is a public non-browser API boundary that intentionally does not use cookie authentication; use the repository API security contract instead.

## Repository inspection
Inspect authentication mode, CSRF configuration, Turbo requests, custom JavaScript requests, and request tests.

## Implementation procedure
Classify the credential boundary, preserve CSRF behavior, and test rejection semantics before adding workarounds.

## Failure modes
Global CSRF disablement, missing request tokens, and mixed-authentication semantics.

## Testing
Test state-changing browser requests with valid and invalid CSRF context.

## Review checklist
CSRF remains a deliberate server-side security control.

## Related skills
rails-hotwire, rails-authentication, rails-security, rails-action-controller

## Use when

Use this pattern when the Hotwire interaction relies on the named security or progressive-enhancement boundary.
