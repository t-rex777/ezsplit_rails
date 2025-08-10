Rails.application.routes.draw do
  resources :categories
  resource :session
  resources :passwords, param: :token
  resources :user_registers, only: %i[ create new ]
  resources :users, only: %i[ index ]
  resources :expenses
  resources :expenses_users, only: %i[ create update destroy ]
  resources :groups do
    resources :group_memberships
  end

  # User search route
  get "users/search", to: "users#search"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :rails_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :rails_service_worker

  # Defines the root path route ("/")
  root "sessions#show"
end
