# frozen_string_literal: true

# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  before_action :delete_current_patient, except: %i[patient_advance_directives]
  before_action :require_server, except: %i[fhir_servers]
  before_action :retrieve_patient, only: %i[patient_advance_directives]

  # GET /pages/patients
  def patients; end

  # GET /pages/fhir_servers
  def fhir_servers; end

  # GET /pages/patients/:id/advance_directives
  def patient_advance_directives; end

  private

  def delete_current_patient
    session.delete(:patient_id)
  end
end
