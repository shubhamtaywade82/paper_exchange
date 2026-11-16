---
name: action-cable-authorization-boundary
description: Authorize realtime connections, subscriptions, streams, and state-changing channel actions.
family: rails
---
# Action Cable Authorization Boundary

## Problem
A valid connection is incorrectly treated as permission for every stream or action.

## Structure
Authorize identity at connection, resource access at subscription/stream, and sensitive mutations at action.

## Example

```ruby
# Identity at the connection, resource access at subscription, sensitive
# mutations re-checked in the action.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = User.find_by(id: cookies.encrypted[:user_id]) || reject_unauthorized_connection
    end
  end
end

class ProjectChannel < ApplicationCable::Channel
  def subscribed
    @project = current_user.projects.find_by(id: params[:project_id])
    @project ? stream_for(@project) : reject
  end

  def rename(data)
    return unless ProjectPolicy.new(current_user, @project.reload).update?

    @project.update!(name: data.fetch("name"))
  end
end
```

## Failure modes
Stream leakage, stale membership, and mutation without resource authorization.

## Testing
Cover unauthorized subscription and action attempts plus membership revocation.

## Use when

Use this pattern when the named security boundary is part of the requested change.

## Do not use when

Do not introduce this pattern when a simpler repository-consistent boundary already proves the required contract.

## Repository inspection

Inspect the existing authorization mechanism, entry points, resource ownership, tenant scope, tests, and versioned dependencies.

## Implementation procedure

Define the authoritative boundary, adapt to repository conventions, preserve denial semantics, and add focused regression coverage.

## Review checklist

[ ] authoritative mechanism preserved
[ ] bypass paths reviewed
[ ] tenant/resource scope explicit
[ ] rejection behavior tested

## Related skills

rails-authorization, rails-authentication, rails-security, rails-test-engineering
