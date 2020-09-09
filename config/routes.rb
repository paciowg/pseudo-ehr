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
  resources :patients
  resources :observations
  resources :practitioner_roles
  resources :contracts
  resources :eltss_questionnaires
  resources :risk_assessments
  resources :observation_eltsses
  resources :related_people
  resources :claims
  resources :service_requests
  resources :goals
  resources :episode_of_cares
  resources :organizations
  resources :conditions
  resources :care_plans
  resources :questionnaire_responses

  get 'questionnaire_responses/index'
  get 'questionnaire_responses/show'

  get '/home',          to: 'home#index'
  get '/dashboard',     to: 'dashboard#index'
  get '/patients/show', to: 'dashboard#index'
  get '/auth/token',    to: 'home#index'

  root 'welcome#index'

  namespace :api do
    namespace :v1 do
      resources :patients,                  only: [:index, :show]
      resources :questionnaire_responses,   only: [:create]
    end
  end
end
