# frozen_string_literal: true

# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
  def index
    return unless server_present?

    flash[:notice] = "You are connected to FHIR Server: #{@fhir_server.base_url}"
    redirect_to pages_patients_path
  end
end
