# app/controllers/fhir_servers_controller.rb
class FhirServersController < ApplicationController
  before_action :delete_current_patient_id
  # GET /fhir_servers
  def index
    if params[:query].present?
      search_term = "%#{params[:query]}%"
      @pagy, @fhir_servers = pagy(
        FhirServer.where('name ILIKE ? OR base_url ILIKE ?', search_term, search_term).order(:name), items: 10
      )
    else
      @pagy, @fhir_servers = pagy(FhirServer.order(:name), items: 10)
    end
    flash.now[:danger] = 'No Fhir Servers found.' if @fhir_servers.empty?
  end

  # DELETE /fhir_servers/:id
  def destroy
    server = FhirServer.find_by(id: params[:id])
    if server&.destroy
      flash[:success] = 'Server was successfully deleted.'
    else
      flash[:danger] = "Cannot delete server with id #{params[:id]}. Server could not be found."
    end
    redirect_to fhir_servers_path
  end
end
