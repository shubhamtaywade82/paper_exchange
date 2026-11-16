---
name: action-text-api-boundary
description: Define stable API representations for Rails Action Text without exposing internal RichText or attachment storage structure.
family: rails
---

# Action Text API Boundary

## Problem

APIs become coupled to Rails internals when ActionText::RichText rows, IDs, or Trix-specific storage are exposed directly.

## Use when

- exposing rich text through JSON APIs;
- accepting rich text from API clients.

## Do not use when

- Action Text never crosses the API boundary.

## Repository inspection

Inspect serializers, API versions, client expectations, editor contract, attachment upload flow, and plain-text/HTML requirements.

## Implementation procedure

1. Choose API representation.
2. Define sanitized HTML/plain-text/structured contract.
3. Keep internal RichText IDs private unless explicitly contractual.
4. Define attachment references separately.
5. Validate/authorize input.
6. Version breaking representation changes.

## Example

```ruby
# The API exposes a documented representation of the content, not the
# ActionText::RichText row, its id, or Trix storage details.
class Api::ArticleSerializer
  def initialize(article)
    @article = article
  end

  def as_json(*)
    {
      id: @article.id,
      title: @article.title,
      body_html: @article.body.to_s,
      body_text: @article.body.to_plain_text
    }
  end
end
```

## Failure modes

- exposing internal table IDs;
- clients coupled to Trix markup;
- unsanitized HTML response;
- attachments represented without authorization.

## Testing

Test request/response schema, sanitization, attachment references, and compatibility.

## Review checklist

- [ ] representation
- [ ] sanitization
- [ ] attachment contract
- [ ] authorization
- [ ] compatibility

## Related skills

rails-action-text, rails-api-integration, rails-security
