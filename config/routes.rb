Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"

      resources :events do
        resource :bookmark, only: [:create, :destroy], controller: :bookmarks
        resources :ticket_tiers, only: [:index, :create, :update, :destroy]
      end

      resources :bookmarks, only: [:index]

      resources :orders, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end
    end
  end
end
