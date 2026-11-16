---
name: controller-content-negotiation
description: Use when one controller endpoint serves multiple HTTP representations or must reject unsupported formats.
family: rails
---

# Controller Content Negotiation

## Problem

Format branches can become accidental API contracts when a controller silently responds to formats that were never intended.

## Use when

- serving HTML and JSON from one endpoint
- defining API errors
- changing respond_to behavior
- diagnosing format mismatch behavior.

## Do not use when

- the endpoint intentionally has one fixed representation.

## Repository inspection

Inspect route constraints, requested formats, serializers/views, respond_to conventions, API versioning, and request tests.

## Implementation procedure

1. List supported representations.
2. Identify how the client selects the representation.
3. Define success and error behavior per supported format.
4. Define unsupported-format behavior.
5. Keep representation code separate from domain behavior.
6. Add request tests per supported and unsupported format.

## Example

```ruby
class ReportsController < ApplicationController
  def show
    @report = current_account.reports.find(params[:id])

    # Only the formats we support; anything else is 406, not an accidental
    # XML or JSON contract.
    respond_to do |format|
      format.html
      format.json { render json: ReportSerializer.new(@report) }
      format.csv { send_data @report.to_csv, filename: "report-#{@report.id}.csv" }
    end
  end
end
```

## Failure modes

- accepting every format by accident
- using request format as an authorization signal
- changing API error shape for one branch
- duplicating business rules per format.

## Testing

Test format selection, content type, status, body schema, and unsupported formats.

## Review checklist

- [ ] supported formats are explicit
- [ ] unsupported formats are deterministic
- [ ] representation logic is separate
- [ ] error representations are tested

## Related skills

rails-action-controller, rails-api-integration, rails-i18n, rails-test-engineering
