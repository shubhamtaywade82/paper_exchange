---
name: n-plus-one-review
description: Detect and correct Rails N+1 query behavior while controlling row explosion, memory use, and query shape.
family: rails
---

# N+1 Review

## Problem

A parent collection triggers one or more additional database queries per row because an association is accessed lazily inside iteration.

## Use when

Reviewing a Rails read path where records are loaded and associated records are accessed repeatedly.

## Do not use when

The association is not actually accessed per record, or when query-plan evidence shows that N+1 is not the measured bottleneck.

## Repository inspection

Inspect the Rails version, Active Record associations, generated SQL/logs, representative cardinality, existing query objects/scopes, and tests that assert query behavior.

## Implementation procedure

1. Reproduce the workload.
2. Capture query count and SQL shape.
3. Identify the lazy association access.
4. Choose among preload, eager_load, includes, joins/selects, or a different read model based on the required result shape.
5. Check row explosion and memory cost.
6. Add a focused regression test for the query contract.
7. Re-measure.

## Example

```ruby
# Before: 1 query for posts + 1 per post for author + 1 per post for comments count.
#   @posts = Post.order(created_at: :desc).limit(20)
#   <%= post.author.name %> <%= post.comments.count %>

class PostsController < ApplicationController
  def index
    @posts = Post.order(created_at: :desc).limit(20)
                 .includes(:author)                 # 1 extra query total
    # comments_count is a counter cache column: no query per row.
  end
end

# Guard in tests: strict loading raises on lazy loads in this action.
class PostsIndexTest < ActionDispatch::IntegrationTest
  test "index renders without lazy loading" do
    Post.strict_loading_by_default = true
    get posts_path
    assert_response :success
  ensure
    Post.strict_loading_by_default = false
  end
end
```

## Failure modes

- eager-loading unused associations
- row multiplication from joins
- loading huge collections into memory
- hiding the N+1 rather than removing it
- fixing one association while another remains lazy
- adding broad query helpers that obscure ownership

## Testing

Test the observable result and, where query count is part of the performance contract, assert a bounded query count using the repository's existing instrumentation/testing convention.

## Review checklist

- [ ] N+1 reproduced or evidenced
- [ ] chosen loading strategy matches query shape
- [ ] row/cardinality impact considered
- [ ] memory impact considered
- [ ] regression coverage added
- [ ] query count re-measured
- [ ] no speculative eager loading introduced

## Related skills

- rails-performance
- rails-active-record
- rails-test-engineering
- ruby-performance
- rails-database-engineering
