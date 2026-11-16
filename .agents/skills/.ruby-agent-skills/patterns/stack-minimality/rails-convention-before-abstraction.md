---
name: rails-convention-before-abstraction
description: Rails Convention Before Abstraction
family: stack-minimality
---
# Rails Convention Before Abstraction

## Problem
A Rails feature often needs only an existing controller, model, route, scope, serializer, or application service.

## Use when
Adding Rails behavior or deciding whether a new service or wrapper is necessary.

## Do not use when
A real boundary has independent ownership, external integration isolation, multiple implementations, or a different lifecycle.

## Repository inspection
Inspect the relevant application boundary, existing implementations, callers, dependencies, and runtime constraints before introducing a new layer.

## Implementation procedure
Search neighboring Rails code and callers. Start at the existing boundary that owns the behavior; add a new abstraction only when it creates real responsibility or change isolation.

## Example

```ruby
# Before: a service object and a presenter for a plain resource update.
# Projects::UpdateService.new(project, params).call; ProjectPresenter.new(project).as_json

# After: the conventional controller action and the model's own validations.
class ProjectsController < ApplicationController
  def update
    @project = current_account.projects.find(params[:id])
    if @project.update(project_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def project_params = params.require(:project).permit(:name, :due_on)
end
```

## Failure modes
Service-per-action proliferation, wrapper controllers, generic BaseService, and for-later extension points.

## Testing
Cover behavior at the owning Rails boundary.

## Review checklist
[ ] repository evidence checked [ ] smallest valid boundary chosen [ ] required guarantees preserved

## Related skills
rails-architecture, rails-action-controller, ruby-service-objects, stack-minimality
