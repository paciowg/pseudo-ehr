class CapabilityStatementController < ApplicationController

  before_action :ensure_session_handler

  def index
    @fhir_client ||= SessionHandler.fhir_client(session.id)
    @base_server_url = SessionHandler.from_storage(session.id, 'connection')&.base_server_url
    @metadata_url = File.join(@base_server_url, 'metadata')

    fhir_response = @fhir_client.client.get(@metadata_url)
    @metadata = FHIR.from_contents(fhir_response.body) # FHIR::CapabilityStatement object

    @fhir_query = "GET #{@metadata_url}"
  end

end
