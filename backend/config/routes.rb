Rails.application.routes.draw do
  namespace :api do
    get 'health', to: 'health#index'
  end
end 