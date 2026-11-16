---
name: action-text-testing
description: Test Rails Action Text deterministically across rich-text persistence, sanitization, authorization, attachments, attachables, rendering, APIs, and performance boundaries.
family: testing
---

# Action Text Testing

## Problem

Rich-text features can pass model tests while failing on sanitization, embedded resources, rendering, or API contracts.

## Use when

- adding/changing Action Text;
- reviewing rich-text security or regression behavior.

## Do not use when

- no Action Text behavior exists.

## Repository inspection

Inspect test framework, Action Text helpers/fixtures, Active Storage test service, authorization helpers, request/API tests, and query/performance tooling.

## Implementation procedure

1. Test rich-text ownership/persistence.
2. Test authorization.
3. Test malicious HTML/link sanitization.
4. Test Active Storage attachments.
5. Test SGID attachables.
6. Test rendering and plain text.
7. Test API representation.
8. Test preload/query behavior where measurable.

## Example

```ruby
class ArticleRichTextTest < ActionDispatch::IntegrationTest
  test "script tags are stripped on render" do
    article = articles(:draft)
    article.update!(body: %(<p>Hi</p><script>alert(1)</script><img src=x onerror=alert(2)>))

    get article_path(article)

    assert_response :success
    assert_no_match(/<script|onerror=/, response.body)
    assert_includes response.body, "<p>Hi</p>"
  end

  test "api exposes html and plain text, not RichText internals" do
    get api_article_path(articles(:published)), as: :json
    assert_equal %w[body_html body_text id title], response.parsed_body.keys.sort
  end
end
```

## Failure modes

- default-locale/default-content-only tests;
- no negative XSS tests;
- attachable authorization omitted;
- live cloud dependency;
- full HTML snapshots.

## Testing

Prefer semantic assertions, security negatives, attachment references, rendering contracts, and deterministic fixture storage.

## Review checklist

- [ ] persistence
- [ ] authorization
- [ ] sanitization
- [ ] attachment/attachable
- [ ] rendering
- [ ] API
- [ ] performance
- [ ] deterministic

## Related skills

rails-action-text, rails-test-engineering, rails-active-storage, rails-security
