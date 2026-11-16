---
name: hotwire-testing
description: Test Turbo and Stimulus behavior at deterministic request, system, and JavaScript boundaries.
family: testing
---
# Hotwire Testing

## Problem
Tests validate only rendered HTML or only the browser, leaving protocol and lifecycle defects undetected.

## Use when
Changing frames, streams, forms, navigation lifecycle, or Stimulus controllers.

## Required cases
Frame response contract, stream actions, status/redirect behavior, authorization, CSRF, controller lifecycle cleanup, and stable target identity.

## Review checklist
Use the smallest deterministic boundary that proves the behavior and add a browser/system test when DOM lifecycle is essential.
## Do not use when
The change has no Hotwire or browser lifecycle contract.

## Repository inspection
Inspect request/system tests, JavaScript test setup, browser drivers, Turbo helpers, and deterministic fixtures.

## Implementation procedure
Test the smallest protocol boundary first, then add browser/system verification when DOM lifecycle is essential.

## Example

```ruby
class CommentsTest < ActionDispatch::IntegrationTest
  test "create responds with a turbo stream that appends to the list" do
    sign_in users(:sam)

    post post_comments_path(posts(:one)), params: { comment: { body: "Nice" } }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(<turbo-stream action="append" target="comments">)
  end
end

class CommentsSystemTest < ApplicationSystemTestCase
  test "new comment appears without a full page load" do
    sign_in users(:sam)
    visit post_path(posts(:one))
    fill_in "Comment", with: "Nice"
    click_on "Post comment"
    within("#comments") { assert_text "Nice" }
  end
end
```

## Failure modes
Only testing snapshots, only testing JavaScript, timing flakes, and missing authorization coverage.

## Testing
Cover frame and stream contracts, status/redirect behavior, security failures, and Stimulus lifecycle cleanup.

## Review checklist
Tests prove both server protocol and client lifecycle behavior where applicable.

## Related skills
rails-hotwire, rails-test-engineering
