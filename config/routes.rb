Rails.application.routes.draw do
  devise_for :users

  resources :cards, only: [:index]
  resources :cart_items, only: [:index, :create, :update, :destroy]

  resources :reservations, only: [:index, :show, :create] do
    member { patch :cancel }
  end

  namespace :admin do
    resources :reservations, only: [:index, :show] do
      member do
        patch :fulfill
        patch :expire
      end
    end
  end

  resource :profile, only: [:edit, :update]

  get '/set_language/:locale', to: 'application#set_language', as: :set_language

  root "cards#index"
end
