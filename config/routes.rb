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
  get 'content/:id', to: 'contents#show', as: :content

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
  get 'patients/:patient_id/nutrition_orders', to: 'nutrition_orders#index', as: 'patient_nutrition_orders'
  get 'patients/:patient_id/service_requests', to: 'service_requests#index', as: 'patient_service_requests'
  get 'patients/:patient_id/observations', to: 'observations#index', as: 'patient_observations'
  get 'patients/:patient_id/observations/:id', to: 'observations#show', as: 'patient_observation'
  get 'patients/:patient_id/conditions', to: 'conditions#index', as: 'patient_conditions'
  get 'patients/:patient_id/goals', to: 'goals#index', as: 'patient_goals'
  get 'patients/:patient_id/transition_of_cares', to: 'transition_of_cares#index', as: 'patient_transition_of_cares'
  post 'patients/:patient_id/transition_of_cares', to: 'transition_of_cares#create'
  patch 'patients/:patient_id/transition_of_cares/:id', to: 'transition_of_cares#update',
                                                        as: 'update_patient_transition_of_care'
  get 'patients/:patient_id/medication_lists', to: 'medication_lists#index', as: 'patient_medication_lists'
  get 'patients/:patient_id/medication_requests', to: 'medication_requests#index', as: 'patient_medication_requests'
  get 'patients/:patient_id/procedures', to: 'procedures#index', as: 'patient_procedures'
  get 'patients/:patient_id/diagnostic_reports', to: 'diagnostic_reports#index', as: 'patient_diagnostic_reports'
  get 'patients/:patient_id/document_references', to: 'document_references#index', as: 'patient_document_references'
end
