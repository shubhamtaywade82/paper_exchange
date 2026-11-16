---
name: action-text-sanitization-security
description: Preserve safe Rails Action Text sanitization and review HTML, links, interpolation, and custom rendering for XSS and content-security risks.
family: rails
---

# Action Text Sanitization Security

## Problem

Rich text is user-controlled structured HTML-like content and can become an XSS boundary if sanitization is bypassed or custom rendering is unsafe.

## Use when

- customizing sanitization;
- rendering rich content;
- changing links or HTML handling.

## Do not use when

- content is not Action Text.

## Repository inspection

Inspect sanitizer configuration, html_safe/raw usage, permitted tags/attributes, link policy, translation behavior, and custom partials.

## Implementation procedure

1. Preserve server-side sanitization.
2. Identify trusted/untrusted markup.
3. Review allowed URL schemes.
4. Review custom HTML/attachment partials.
5. Add malicious HTML/link tests.
6. Verify final rendered output.

## Example

```ruby
# config/initializers/action_text.rb
# Narrow, reviewed changes to the default allowlist; never add script,
# style, iframe, or event-handler attributes to "fix" rendering.
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_tags = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + %w[mark]
  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a - %w[style]
end
```

## Failure modes

- bypassed sanitizer;
- raw user HTML marked safe;
- unsafe URL schemes;
- custom partial leaks;
- trusted translation path accepts untrusted content.

## Testing

Test script/event payloads, unsafe URLs, malformed markup, and expected safe formatting.

## Review checklist

- [ ] server sanitizer
- [ ] URL policy
- [ ] escaping
- [ ] custom renderer
- [ ] negative tests

## Related skills

rails-action-text, rails-security, rails-security-engineering, rails-action-view
