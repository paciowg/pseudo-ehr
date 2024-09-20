Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root 'welcome#index'
  resources :sessions, only: [:new]
  resources :patients, only: %i[show index]
  resources :fhir_servers, only: %i[index destroy]

  get 'welcome/index'
  get 'pdf/:binary_id', to: 'pdfs#show', as: :pdf
  get 'pages/patients'
  get 'pages/fhir_servers'
  get 'pages/patients/:id/advance_directives', to: 'pages#patient_advance_directives',
                                               as: 'patient_advance_directives_page'

  get 'pages/advance_directives/:id', to: 'pages#advance_directive', as: 'advance_directive_page'
  get 'pages/patients/:id/care_teams', to: 'pages#patient_care_teams', as: 'patient_care_teams_page'
  get 'pages/patients/:id/questionnaire_responses', to: 'pages#patient_questionnaire_responses',
                                                    as: 'patient_questionnaire_responses_page'
  get 'pages/patients/:patient_id/questionnaire_responses/:id', to: 'pages#patient_questionnaire_response',
                                                                as: 'patient_questionnaire_response_page'
  get 'pages/patients/:id/observations', to: 'pages#patient_observations', as: 'patient_observations_page'
  get 'pages/patients/:patient_id/observations/:id', to: 'pages#patient_observation', as: 'patient_observation_page'
  get 'pages/patients/:id/conditions', to: 'pages#patient_conditions', as: 'patient_conditions_page'
  get 'pages/patients/:patient_id/conditions/:id', to: 'pages#patient_condition', as: 'patient_condition_page'
  get 'pages/patients/:id/goals', to: 'pages#patient_goals', as: 'patient_goals_page'
  get 'pages/patients/:patient_id/goals/:id', to: 'pages#patient_goal', as: 'patient_goal_page'
  get 'pages/patients/:patient_id/transition_of_care', to: 'pages#patient_transition_of_care',
                                                       as: 'patient_transition_of_care_page'
  get 'pages/patients/:patient_id/medication_lists', to: 'pages#patient_medication_lists',
                                                     as: 'patient_medication_lists_page'

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
  get 'patients/:patient_id/observations', to: 'observations#index', as: 'patient_observations'
  get 'patients/:patient_id/observations/:id', to: 'observations#show', as: 'patient_observation'
  get 'patients/:patient_id/conditions', to: 'conditions#index', as: 'patient_conditions'
  get 'patients/:patient_id/conditions/:id', to: 'conditions#show', as: 'patient_condition'
  get 'patients/:patient_id/goals', to: 'goals#index', as: 'patient_goals'
  get 'patients/:patient_id/goals/:id', to: 'goals#show', as: 'patient_goal'
  get 'patients/:patient_id/transition_of_care', to: 'transition_of_cares#show', as: 'patient_transition_of_care'
  get 'patients/:patient_id/medication_lists', to: 'medication_lists#index', as: 'patient_medication_lists'
end
