Rails.application.routes.draw do
  devise_for :users

  resources :cards, only: [:index]
  resources :cart_items, only: [:index, :create, :update, :destroy]

  resource :profile, only: [:edit, :update]

  root "cards#index"
end
