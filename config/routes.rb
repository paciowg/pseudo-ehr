Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root 'welcome#index'
  resources :sessions, only: [:new]
  resources :patients, only: %i[show index] do
    post :sync_patient_record, on: :member
  end
  resources :fhir_servers, only: %i[index destroy]

  get 'welcome/index'
  get 'pdf/:binary_id', to: 'pdfs#show', as: :pdf

  get '/login', to: 'sessions#login'
  post '/launch', to: 'sessions#launch_server'
  get '/disconnect', to: 'sessions#disconnect_server'
  get 'patients/:patient_id/advance_directives', to: 'advance_directives#index', as: 'patient_advance_directives'
  get 'advance_directives/:id', to: 'advance_directives#show', as: 'advance_directive'
  put 'advance_directives/:id', to: 'advance_directives#update_pmo'
  get 'advance_directives/:id/revoke', to: 'advance_directives#revoke_living_will'
  get 'patients/:patient_id/care_teams', to: 'care_teams#index', as: 'patient_care_teams'
  get 'patients/:patient_id/questionnaire_responses', to: 'questionnaire_responses#index',
                                                      as: 'patient_questionnaire_responses'
  get 'patients/:patient_id/questionnaire_responses/:id', to: 'questionnaire_responses#show',
                                                          as: 'patient_questionnaire_response'
  get 'patients/:patient_id/nutrition_orders', to: 'nutrition_orders#index', as: 'patient_nutrition_orders'
  get 'patients/:patient_id/service_requests', to: 'service_requests#index', as: 'patient_service_requests'
  get 'patients/:patient_id/observations', to: 'observations#index', as: 'patient_observations'
  get 'patients/:patient_id/observations/:id', to: 'observations#show', as: 'patient_observation'
  get 'patients/:patient_id/conditions', to: 'conditions#index', as: 'patient_conditions'
  get 'patients/:patient_id/conditions/:id', to: 'conditions#show', as: 'patient_condition'
  get 'patients/:patient_id/goals', to: 'goals#index', as: 'patient_goals'
  get 'patients/:patient_id/transition_of_care', to: 'transition_of_cares#show', as: 'patient_transition_of_care'
  get 'patients/:patient_id/medication_lists', to: 'medication_lists#index', as: 'patient_medication_lists'
end
