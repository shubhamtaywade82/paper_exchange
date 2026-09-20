Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resources :orders, only: %i[index show create destroy]
    resources :positions, only: %i[index show]
    resources :risk_events, only: %i[index]
    get "performance", to: "performance#show"
    resources :ledger, only: %i[index]
    post "mark_prices", to: "mark_prices#create"
    post "funding_events", to: "funding_events#create"
  end
end
