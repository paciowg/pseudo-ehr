# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root 'welcome#index'
  resources :sessions, only: [:new]
  resources :patients, only: %i[show index]
  resources :fhir_servers, only: %i[index destroy]

  get 'welcome/index'
  get 'pages/patients'
  get 'pages/fhir_servers'
  get '/login', to: 'sessions#login'
  post '/launch', to: 'sessions#launch_server'
  get '/disconnect', to: 'sessions#disconnect_server'
  get 'patients/:patient_id/advance_directives', to: 'advance_directives#index'
  get 'advance_directives/:id', to: 'advance_directives#show'
  put 'advance_directives/:id', to: 'advance_directives#update_pmo'
  put 'advance_directives/:id/revoke', to: 'advance_directives#revoke_living_will'
end
