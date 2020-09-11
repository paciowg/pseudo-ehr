################################################################################
#
# Application Routes Configuration
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

# For details on the DSL available within this file, see 
# http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do

  # Define 'EHR' web app routes

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
  get '/login',         to: 'home#index'
  get '/auth/token',    to: 'home#index'
  get '/env',           to: 'env#index'
  get '/convert',       to: 'convert#index'
  put '/convert/:id',   to: 'convert#update'

  root 'welcome#index'

  # Define 'FHIR' API for retrieving patients and converting questionnaire 
  # response resources posts to PACIO resources

  namespace :api do
    namespace :v1 do
      # Make this compatible with the way other FHIR servers handle resources
      get 'Patient',      to: 'patients#index',   as: :patients
      get 'Patient/:id',  to: 'patients#show',    as: :patient

      post 'QuestionnaireResponse', to: 'questionnaire_responses#create', 
                    as: :questionnaire_responses
    end
  end
  
end
