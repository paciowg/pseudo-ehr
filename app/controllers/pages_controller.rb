# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  before_action :delete_current_patient_id, only: %i[patients fhir_servers]
  before_action :require_server, except: %i[fhir_servers]
  before_action :retrieve_patient, :set_resources_count, except: %i[patients fhir_servers]

  # GET /pages/patients
  def patients; end

  # GET /pages/fhir_servers
  def fhir_servers; end

  # GET /pages/patients/:id/advance_directives
  def patient_advance_directives; end

  # GET /pages/advance_directives/:id
  def advance_directive
    @adi_id = params[:id]
  end

  # GET /pages/patients/:id/care_teams
  def patient_care_teams; end

  # GET /pages/patients/:id/questionnaire_responses
  def patient_questionnaire_responses; end

  # GET /pages/patients/:patient_id/questionnaire_responses/:id
  def patient_questionnaire_response
    @questionnaire_response_id = params[:id]
  end

  # GET /pages/patients/:id/nutrition_orders
  def patient_nutrition_orders; end

  # GET /pages/patients/:id/service_requests
  def patient_service_requests; end

  # GET /pages/patients/:id/observations
  def patient_observations; end

  # GET pages/patients/:patient_id/observations/:id'
  def patient_observation
    @observation_id = params[:id]
  end

  # GET /pages/patients/:id/conditions
  def patient_conditions; end

  # GET /pages/patients/:patient_id/conditions/:id
  def patient_condition
    @condition_id = params[:id]
  end

  # GET /pages/patients/:id/goals
  def patient_goals; end

  # GET /pages/patients/:patient_id/goals/:id
  def patient_goal
    @goal_id = params[:id]
  end

  # GET /pages/patients/:patient_id/transition_of_cares/:id
  def patient_transition_of_care
    @toc_id = params[:id]
  end

  # GET /pages/patients/:id/medication_lists
  def patient_medication_lists; end
end
