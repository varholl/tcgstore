Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  constraints ->(request) { request.env["warden"].user&.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  resources :cards, only: [:index]
  resources :cart_items, only: [:index, :create, :update, :destroy]

  resources :reservations, only: [:index, :show, :create] do
    member { patch :cancel }
  end

  namespace :admin do
    resources :reservations, only: [:index, :show, :new, :create] do
      collection do
        get :search_cards
        get :import
        post :create_import
      end
      member do
        patch :pay
        patch :fulfill
        patch :expire
        patch :update_final_price
        patch :update_item_price
        delete :remove_item
        post :add_item
        get :search_cards_for_add
      end
      resources :notes, only: [:create], controller: 'reservation_notes'
    end
    resources :users, only: [:index, :show, :edit, :update, :destroy]
    resources :cards, except: [:show] do
      collection do
        get :search_scryfall
        post :refresh_prices
      end
      member do
        patch :mark_price_reviewed
      end
    end
  end

  resource :profile, only: [:edit, :update]

  get 'how_it_works', to: 'pages#how_it_works'
  get 'about', to: 'pages#about'
  post '/set_language/:locale', to: 'application#set_language', as: :set_language

  root "cards#index"
end
