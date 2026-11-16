---
name: route-scope-namespace-contract
description: Use when changing Rails namespaces, scope path/module/as dimensions, or controller routing modules.
family: rails
---

# Route Scope and Namespace Contract

## Problem

Rails scopes can independently change URL paths, controller modules, and helper names; conflating these dimensions causes accidental public or internal API changes.

## Use when

- adding namespace or scope;
- moving controllers without changing URLs;
- changing helper prefixes or API paths.

## Do not use when

- controller implementation changes without routing changes.

## Repository inspection

Inspect controllers/modules, route helpers, existing URLs, API/version conventions, and tests. Compare desired path, module, and helper dimensions independently.

## Implementation procedure

1. Specify desired public path.
2. Specify desired controller module.
3. Specify desired helper prefix.
4. Choose namespace, scope module, scope path, scope as, or explicit options accordingly.
5. Verify generated routes and helpers before changing callers.

## Example

```ruby
Rails.application.routes.draw do
  # namespace: path /admin, controllers Admin::, helpers admin_*
  namespace :admin do
    resources :users # admin_users_path -> Admin::UsersController
  end

  # scope module: controllers Api::V1:: only; path and helpers unchanged by module
  scope "api/v1", module: "api/v1", as: "api_v1" do
    resources :orders # /api/v1/orders, api_v1_orders_path -> Api::V1::OrdersController
  end

  # scope path only: URL prefix, same controllers and helper names
  scope "(:locale)", locale: /en|hi/ do
    resources :products # products_path -> ProductsController
  end
end
```

## Failure modes

- namespace changes multiple dimensions unexpectedly;
- helper names change without caller migration;
- route module diverges from repository structure;
- namespace mistaken for authorization.

## Testing

Assert representative path, controller, and helper contracts. Test protected namespace access through the actual authorization boundary.

## Review checklist

- [ ] path/module/helper dimensions are explicit
- [ ] helper compatibility considered
- [ ] controller namespace exists
- [ ] namespace is not authorization

## Related skills

rails-routing, rails-action-controller, rails-authentication
