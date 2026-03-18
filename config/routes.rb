Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  constraints ->(request) { request.env["warden"].user&.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  resources :cards, only: [:index] do
    collection do
      post :dismiss_how_it_works
    end
  end
  resources :cart_items, only: [:index, :create, :update, :destroy] do
    collection do
      delete :destroy_all
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
    end
  end

  namespace :admin do
    resource :site_settings, only: [:edit, :update]
    resources :reservations, only: [:index, :show, :new, :create] do
      collection do
        get :search_cards
        get :import
        post :create_import
      end
      member do
        patch :prepare
        patch :pay
        patch :fulfill
        patch :revert_to_paid
        patch :expire
        patch :update_final_price
        patch :update_item_price
        delete :remove_item
        post :add_item
        get :search_cards_for_add
      end
      resources :notes, only: [:create], controller: 'reservation_notes'
    end
    resources :users, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :cards, except: [:show] do
      collection do
        get :search_scryfall
        post :refresh_prices
      end
      member do
        patch :mark_price_reviewed
        patch :refresh_price
      end
    end
    resources :stock_reconciliations, only: [:new, :create] do
      collection do
        get :export
      end
    end
  end

  resource :profile, only: [:edit, :update]

  get 'how_it_works', to: 'pages#how_it_works'
  get 'about', to: 'pages#about'
  post '/set_language/:locale', to: 'application#set_language', as: :set_language
  post '/toggle_theme', to: 'application#toggle_theme', as: :toggle_theme

  root "cards#index"
end
