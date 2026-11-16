---
name: active-storage-serving
description: Choose and enforce safe Active Storage serving, redirect, proxy, CDN, and authenticated-controller semantics for private or public files.
family: rails
---

# Active Storage Serving

## Problem

File delivery can accidentally bypass application authorization when default blob routes are treated as ordinary controller routes.

## Use when

- serving private files;
- adding download endpoints;
- adding a CDN/proxy;
- deciding public versus authenticated access.

## Do not use when

- file delivery is purely internal and the repository already has a proven boundary.

## Repository inspection

Inspect default Active Storage routes, route configuration, authentication, resource ownership, signed URL lifetime, proxy/redirect mode, CDN configuration, and tests.

## Implementation procedure

1. Classify file visibility.
2. Authorize against the owning resource.
3. Choose redirect/proxy/domain-owned controller.
4. Review URL lifetime and leakage.
5. Configure CDN/cache only when the access contract permits it.
6. Disable conflicting public routes when required.
7. Test unauthorized access.

## Example

```ruby
# Private files: an authorized controller action redirects to a short-lived
# URL, instead of exposing the default /rails/active_storage routes.
class InvoicePdfsController < ApplicationController
  def show
    invoice = current_account.invoices.find(params[:invoice_id])
    redirect_to invoice.pdf.url(expires_in: 5.minutes, disposition: :attachment), allow_other_host: true
  end
end

# config/routes.rb
#   resources :invoices, only: [] do
#     resource :pdf, only: :show, controller: "invoice_pdfs"
#   end
# config/application.rb
#   config.active_storage.draw_routes = false # public blob routes disabled
```

## Failure modes

- blob-ID authorization;
- permanent signed URL treated as session authorization;
- CDN cache shared across tenants;
- private file served through public routes.

## Testing

Test authorized access, unauthorized access, tenant isolation, route configuration, and cache behavior where applicable.

## Review checklist

- [ ] visibility classified
- [ ] owner authorization
- [ ] serving mode explicit
- [ ] URL leakage considered
- [ ] CDN/cache isolation reviewed

## Related skills

rails-active-storage, rails-security, rails-caching, rails-observability
