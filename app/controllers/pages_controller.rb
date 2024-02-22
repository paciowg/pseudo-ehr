# frozen_string_literal: true

# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  before_action :delete_current_patient,
                except: %i[patient_advance_directives advance_directive patient_care_teams
                           patient_questionnaire_responses patient_questionnaire_response
                           patient_observations patient_observation patient_conditions patient_condition
                           patient_goals patient_goal]
  before_action :require_server, except: %i[fhir_servers]
  before_action :retrieve_patient,
                only: %i[patient_advance_directives advance_directive patient_care_teams
                         patient_questionnaire_responses patient_questionnaire_response
                         patient_observations patient_observation patient_conditions patient_condition
                         patient_goals patient_goal]

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

  private

  def delete_current_patient
    session.delete(:patient_id)
  end
end
