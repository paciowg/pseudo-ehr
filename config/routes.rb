Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root 'welcome#index'
  # Mount ActionCable server
  mount ActionCable.server => '/cable'

  # Task Status routes
  post 'task_statuses/:task_id/dismiss', to: 'task_statuses#dismiss'
  resources :sample_data, only: [:index] do
    collection do
      get :load_data
      post :push_data
    end
  end
  namespace :api do
    post 'convert_qr_to_pfe_and_submit',
         to: 'questionnaire_response_processing#convert_qr_to_pfe_and_submit',
         as: :convert_qr_to_pfe_and_submit
  end

  resources :sessions, only: [:new]
  resources :patients, only: %i[show index update] do
    post :sync_patient_record, on: :member
  end
  resources :fhir_servers, only: %i[index destroy]

  get 'welcome/index'
  get 'content/:id', to: 'contents#show', as: :content

  get '/login', to: 'sessions#login'
  post '/launch', to: 'sessions#launch_server'
  get '/disconnect', to: 'sessions#disconnect_server'

  # Advance Directive routes
  get 'patients/:patient_id/advance_directives', to: 'advance_directives#index', as: 'patient_advance_directives'
  get 'advance_directives/:id', to: 'advance_directives#show', as: 'advance_directive'
  put 'advance_directives/:id', to: 'advance_directives#update_pmo'
  get 'advance_directives/:id/revoke', to: 'advance_directives#revoke_living_will'

  # Care Teams routes
  get 'patients/:patient_id/care_teams', to: 'care_teams#index', as: 'patient_care_teams'

  # QuestionnaireReesponse routes
  get 'patients/:patient_id/questionnaire_responses', to: 'questionnaire_responses#index',
                                                      as: 'patient_questionnaire_responses'
  post 'patients/:patient_id/questionnaire_responses/:id/convert_to_assessments',
       to: 'questionnaire_responses#convert_to_assessments',
       as: 'convert_questionnaire_response_to_assessments'

  # NutritionOrder routes
  get 'patients/:patient_id/nutrition_orders', to: 'nutrition_orders#index', as: 'patient_nutrition_orders'
  post 'patients/:patient_id/nutrition_orders', to: 'nutrition_orders#create'
  patch 'patients/:patient_id/nutrition_orders/:id', to: 'nutrition_orders#update',
                                                      as: 'update_patient_nutrition_order'
  delete 'patients/:patient_id/nutrition_orders/:id', to: 'nutrition_orders#delete',
                                          as: 'delete_patient_nutrition_order'

  # ServiceRequest routes
  get 'patients/:patient_id/service_requests', to: 'service_requests#index', as: 'patient_service_requests'
  post 'patients/:patient_id/service_reqeusts', to: 'service_requests#create'
  patch 'patients/:patient_id/service_requests/:id', to: 'service_requests#update',
                                                      as: 'update_patient_service_request'
  delete 'patients/:patient_id/service_requests/:id', to: 'service_requests#delete',
                                          as: 'delete_patient_service_request'

  # Observation routes
  get 'patients/:patient_id/observations', to: 'observations#index', as: 'patient_observations'
  get 'patients/:patient_id/observations/:id', to: 'observations#show', as: 'patient_observation'
  post 'patients/:patient_id/observations', to: 'observations#create'
  patch 'patients/:patient_id/observations/:id', to: 'observations#update',
                                                  as: 'update_patient_observation'
  delete 'patients/:patient_id/observations/:id', to: 'observations#delete',
                                          as: 'delete_patient_observation'

  # Condition routes
  get 'patients/:patient_id/conditions', to: 'conditions#index', as: 'patient_conditions'
  post 'patients/:patient_id/conditions', to: 'conditions#create'
  patch 'patients/:patient_id/conditions/:id', to: 'conditions#update',
                                                      as: 'update_patient_condition'
  delete 'patients/:patient_id/conditions/:id', to: 'conditions#delete',
                                          as: 'delete_patient_condition'
  
  # Goal routes
  get 'patients/:patient_id/goals', to: 'goals#index', as: 'patient_goals'
  post 'patients/:patient_id/goals', to: 'goals#create'
  patch 'patients/:patient_id/goals/:id', to: 'goals#update',
                                          as: 'update_patient_goal'
  delete 'patients/:patient_id/goals/:id', to: 'goals#delete',
                                          as: 'delete_patient_goal'
  
  # DetectedIssue routes
  get 'patients/:patient_id/detected_issues', to: 'detected_issues#index', as: 'patient_detected_issues'

  # TransitionOfCare routes
  get 'patients/:patient_id/transition_of_cares', to: 'transition_of_cares#index', as: 'patient_transition_of_cares'
  post 'patients/:patient_id/transition_of_cares', to: 'transition_of_cares#create'
  patch 'patients/:patient_id/transition_of_cares/:id', to: 'transition_of_cares#update',
                                                        as: 'update_patient_transition_of_care'

  get 'patients/:patient_id/medication_lists', to: 'medication_lists#index', as: 'patient_medication_lists'

  # MedicationRequest routes
  get 'patients/:patient_id/medication_requests', to: 'medication_requests#index', as: 'patient_medication_requests'
  post 'patients/:patient_id/medication_requests', to: 'medication_requests#create'
  patch 'patients/:patient_id/medication_requests/:id', to: 'medication_requests#update',
                                          as: 'update_patient_medication_request'
  delete 'patients/:patient_id/medication_requests/:id', to: 'medication_requests#delete',
                                          as: 'delete_patient_medication_request'

  get 'patients/:patient_id/procedures', to: 'procedures#index', as: 'patient_procedures'
  get 'patients/:patient_id/diagnostic_reports', to: 'diagnostic_reports#index', as: 'patient_diagnostic_reports'
  get 'patients/:patient_id/document_references', to: 'document_references#index', as: 'patient_document_references'
end
