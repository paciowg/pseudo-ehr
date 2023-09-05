# frozen_string_literal: true

# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  before_action :delete_current_patient
  before_action :require_server, only: %i[patients]

  # GET /pages/patients
  def patients; end

  # GET /pages/fhir_servers
  def fhir_servers; end

  private

  def delete_current_patient
    session.delete(:patient_id)
  end
end
