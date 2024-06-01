Rails.application.routes.draw do
  get  'setup/index'
  get  '/',         to: 'home#index'
  get  '/callback', to: 'home#callback'
  get  '/setup',    to: 'home#setup'
  post '/setup',    to: 'home#save_setup'
  get  '/logout',   to: 'home#log_out'
  get  '/auth',     to: 'home#auth'
  post '/generate', to: 'home#generate_daily_drive'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
