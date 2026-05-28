Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  constraints ->(request) { request.env["warden"].user&.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  namespace :api, defaults: { format: :json } do
    resources :cards, only: [:index]
  end

  resources :cards, only: [:index] do
    collection do
      post :dismiss_how_it_works
    end
  end
  get '/card', to: 'cards#show', as: :card_lookup
  get '/card/:id', to: 'cards#show', as: :card
  get '/search', to: redirect { |_p, req| "/cards?#{req.query_string}" }
  resources :cart_items, only: [:index, :create, :update, :destroy] do
    collection do
      delete :destroy_all
      post :bulk_add
    end
  end

  resources :reservations, only: [:index, :show, :create] do
    member do
      patch :cancel
      patch :set_payment_method
      post :upload_receipt
      delete :remove_item
      post :add_item
      get :search_cards
      patch :update_shipping_info
      patch :update_shipping_method
    end
    resources :notes, only: [:create], controller: 'reservation_notes'
  end

  namespace :admin do
    get "dashboard", to: "dashboard#index", as: :dashboard
    get "dashboard/search_cards", to: "dashboard#search_cards", as: :dashboard_search_cards
    post "dashboard/walk_in", to: "dashboard#walk_in", as: :dashboard_walk_in
    resource :site_settings, only: [:edit, :update]
    resources :reservations, only: [:index, :show, :new, :create] do
      collection do
        get :search_cards
        get :import
        post :create_import
      end
      member do
        patch :in_preparation
        patch :prepare
        patch :pay
        patch :ship
        patch :update_tracking
        patch :fulfill
        patch :revert_to_paid
        patch :expire
        patch :update_final_price
        patch :update_delivery
        patch :update_shipping_method
        patch :update_shipping_address
        patch :force_decrement
        patch :toggle_trade
        patch :update_item_price
        patch :toggle_item_prepared
        patch :update_item_issue
        delete :remove_item
        post :add_item
        get :search_cards_for_add
      end
      resources :notes, only: [:create], controller: 'reservation_notes'
      resources :payments, only: [:create, :destroy], controller: 'reservation_payments'
    end
    resources :users, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :sellers, except: [:show] do
      member do
        patch :toggle_suspended
      end
    end
    resources :cards, except: [:show] do
      collection do
        get :search_scryfall
        post :refresh_prices
        post :fetch_metadata
        patch :bulk_update_language
        post :mark_set_as_new
      end
      member do
        patch :mark_price_reviewed
        patch :refresh_price
        post :add_stock
        patch :update_stock_entry
        delete :remove_stock_entry
      end
    end
    resources :stock_reconciliations, only: [:new, :create] do
      collection do
        get :export
      end
    end
  end

  resources :bulk_searches, only: [:index] do
    collection do
      get :search
    end
  end

  resource :profile, only: [:edit, :update]

  get 'how_it_works', to: 'pages#how_it_works'
  get 'about', to: 'pages#about'
  post '/set_language/:locale', to: 'application#set_language', as: :set_language
  post '/toggle_theme', to: 'application#toggle_theme', as: :toggle_theme

  root "cards#index"
end
