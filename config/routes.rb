Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  concern :api_endpoints do
    get "account", to: "accounts#show"
    post "account/reset", to: "accounts#reset"
    resources :orders, only: %i[index show create destroy]
    resources :positions, only: %i[index show]
    resources :risk_events, only: %i[index]
    get "performance", to: "performance#show"
    resources :ledger, only: %i[index]
    post "mark_prices", to: "mark_prices#create"
    post "mark-prices", to: "mark_prices#create"
    post "funding_events", to: "funding_events#create"
    post "funding-events", to: "funding_events#create"
    get "market_events", to: "market_events#index"
    post "market_events", to: "market_events#create"
    get "market-events", to: "market_events#index"
    post "market-events", to: "market_events#create"
    get "market_structure", to: "market_structure#index"
    post "market_structure", to: "market_structure#create"
    get "market-structure", to: "market_structure#index"
    post "market-structure", to: "market_structure#create"
    post "strategy/signals", to: "strategy#create"
    post "strategy-signals", to: "strategy#create"
  end

  namespace :api do
    concerns :api_endpoints
    scope :v1 do
      concerns :api_endpoints
    end
  end
end
