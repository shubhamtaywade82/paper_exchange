---
name: route-helper-contract
description: Use when changing Rails route names, path/url helpers, polymorphic routing, route parameters, or object-based URL generation.
family: rails
---

# Route Helper Contract

## Problem

Route declarations generate helpers that become application-wide contracts; changing helper names or object-to-route semantics can break callers without changing controller code.

## Use when

- changing as, param, path, or nesting;
- changing polymorphic routing;
- introducing direct/resolve mappings;
- debugging generated URLs.

## Do not use when

- no path/URL generation is affected.

## Repository inspection

Search helper callers, to_param, model naming, route names, mailer/job/serializer uses, and route-generation tests.

## Implementation procedure

1. Record current helper names and signatures.
2. Identify caller categories.
3. Change declarations intentionally.
4. Verify generated path and URL helpers.
5. Test persisted/new-record object routing where applicable.
6. Migrate callers in the same coherent change when compatibility is intentionally broken.

## Example

```ruby
Rails.application.routes.draw do
  resources :products, param: :slug # product_path(product) uses product.to_param
end

class Product < ApplicationRecord
  def to_param = slug # changing this changes every generated URL
end

# test/routing/product_routes_test.rb pins the helper contract.
class ProductRoutesTest < ActionDispatch::IntegrationTest
  test "product helper uses the slug" do
    assert_equal "/products/red-mug", product_path(Product.new(slug: "red-mug"))
    assert_recognizes({ controller: "products", action: "show", slug: "red-mug" }, "/products/red-mug")
  end
end
```

## Failure modes

- renamed helper with stale callers;
- wrong parent/child object order;
- unstable to_param behavior;
- singular mapping missing;
- absolute URL generated with an unexpected host.

## Testing

Test helper names/signatures, polymorphic paths, and representative absolute URLs when those are public contracts.

## Review checklist

- [ ] helper contract inventoried
- [ ] to_param/model naming inspected
- [ ] persisted/new-record behavior covered
- [ ] path vs URL use intentional

## Related skills

rails-routing, rails-action-view, rails-action-mailer, rails-i18n
