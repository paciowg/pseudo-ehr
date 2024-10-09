# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
  def index
    return unless server_present?

    flash[:notice] = "You are connected to FHIR Server: #{@current_server.base_url}"
    redirect_to patients_path
  end
end
