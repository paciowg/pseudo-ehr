################################################################################
#
# Application Routes Configuration
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do

  resources :functional_status,   only: [:index, :show]
  resources :cognitive_status, 	  only: [:index, :show]
  resources	:practitioners,       only: [:show]

  get '/home', to: 'home#index'
  get '/dashboard', to: 'dashboard#index'

  root 'welcome#index'

  namespace :api do
    namespace :v1 do
      resources :patients,                  only: [:index, :show]
      resources :questionnaire_responses,   only: [:create]
    end
  end
end
