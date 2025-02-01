Rails.application.routes.draw do
  resources :playlists
  get  '/',         to: 'home#index'
  get  '/callback', to: 'home#callback'
  get  '/setup',    to: 'setup#index'
  post '/setup',    to: 'setup#save_setup'
  get  '/signout',  to: 'setup#sign_out'
  get  '/auth',     to: 'home#auth'
  post '/generate', to: 'setup#generate_playlist'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
