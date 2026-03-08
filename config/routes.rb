Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  resources :cards, only: [:index]
  resources :cart_items, only: [:index, :create, :update, :destroy]

  resources :reservations, only: [:index, :show, :create] do
    member { patch :cancel }
  end

  namespace :admin do
    resources :reservations, only: [:index, :show, :new, :create] do
      collection do
        get :search_cards
      end
      member do
        patch :pay
        patch :fulfill
        patch :expire
      end
    end
  end

  resource :profile, only: [:edit, :update]

  get 'how_it_works', to: 'pages#how_it_works'
  get 'about', to: 'pages#about'
  post '/set_language/:locale', to: 'application#set_language', as: :set_language

  root "cards#index"
end
