---
name: action-view-output-safety
description: Review and implement safe HTML rendering in Action View without bypassing Rails escaping or sanitizer boundaries.
family: rails
---

# Action View Output Safety

## Problem

Presentation code can accidentally turn untrusted strings into executable HTML.

## Use when

- using raw, html_safe, safe_join, or sanitize;
- rendering user-controlled HTML;
- reviewing XSS regressions;
- changing sanitizer configuration.

## Do not use when

- output is plain text and standard escaping remains untouched.

## Repository inspection

Inspect current escaping behavior, sanitizer configuration, trusted content sources, user-generated HTML, Action Text usage, and security tests.

## Implementation procedure

1. Identify the data source and trust level.
2. Keep default escaping enabled for untrusted strings.
3. Use sanitize when intentionally accepting constrained HTML.
4. Minimize custom sanitizer allowlists.
5. Isolate trusted markup construction from untrusted values.
6. Add malicious-markup and unsafe-URL regression tests.
7. Review caches and translations when rendered output is shared.

## Example

```ruby
module CommentsHelper
  # Escaped by default; tags are built with helpers, joined safely, and user
  # HTML goes through the sanitizer allowlist — never html_safe on input.
  def comment_meta(comment)
    safe_join([tag.strong(comment.author_name), " · ", time_tag(comment.created_at)])
  end

  def comment_body(comment)
    sanitize(comment.body_html, tags: %w[p br strong em a ul ol li], attributes: %w[href])
  end
end
```

## Failure modes

- raw user input;
- broad sanitizer allowlists;
- trusting MIME/content labels;
- marking translated strings HTML-safe without review;
- cache leakage of sanitized private content.

## Testing

Include representative tags, event handlers, unsafe schemes such as javascript:, and mixed trusted/untrusted output.

## Review checklist

- [ ] trust level explicit
- [ ] escaping preserved
- [ ] sanitizer policy bounded
- [ ] unsafe URLs covered
- [ ] cache/privacy impact reviewed

## Related skills

- skills/rails-action-view/SKILL.md
- skills/rails-security/SKILL.md
- skills/rails-security-engineering/SKILL.md
- skills/rails-action-text/SKILL.md
