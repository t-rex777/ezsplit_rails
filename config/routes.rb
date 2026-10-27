Rails.application.routes.draw do
  resources :categories
  resource :session
  resources :passwords, param: :token
  resources :user_registers, only: %i[ create new ]
  resources :users, only: %i[ index ]
  resources :expenses
  resources :settlements, only: %i[ index create destroy ]
  resources :balances, only: %i[ index ]
  resource :summary, only: %i[ show ]
  resource :me, only: %i[ show update ], controller: "me"
  resources :invitations,  only: %i[ create update ]

  # Invite email landing page; hands the invite to the mobile app.
  get "register", to: "registrations#show"

  resources :groups do
    post :add_members, on: :member
    get :balances, on: :member, to: "balances#group"
    get :totals, on: :member
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
