Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resources :orders, only: %i[index show create destroy]
    resources :positions, only: %i[index show]
    resources :risk_events, only: %i[index]
    resource :performance, only: %i[show]
    resources :ledger, only: %i[index]
  end
end
