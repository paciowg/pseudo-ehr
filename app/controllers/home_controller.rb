################################################################################
#
# Home Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class HomeController < ApplicationController

  before_action :establish_session_handler, only: [ :index ]

  #-----------------------------------------------------------------------------

  def index
    # Get list of patients from cached results from server
    @patients = Rails.cache.read("patients")
    @patients = nil
    if @patients.nil?
      # No cached patients, either because it's the first time or the cache
      # has expired.  Make a call to the FHIR server to get the patient list.

      # Temporary code to pull only the patient that has cognitive and functional
      # status in the default server.
      if SessionHandler.from_storage(session.id, "connection").base_server_url == DEFAULT_SERVER
        searchParam = { search: { parameters: { _id: 'cms-patient-01' } } }
        bundle = SessionHandler.fhir_client(session.id).search(FHIR::Patient, searchParam).resource
      else
        bundle = SessionHandler.fhir_client(session.id).search(FHIR::Patient).resource
      end

      @patients = bundle.entry.collect{ |singleEntry| singleEntry.resource } unless bundle.nil?
      if @patients.nil?
        SessionHandler.disconnect(session.id)

        err = "Connection failed: Ensure provided url points to a valid FHIR server"
        err += " that holds at least one patient"
        redirect_to root_path, flash: { error: err }
      else
        # Cache the results so we don't burden the server.
        Rails.cache.write("patients", @patients, expires_in: 1.hour)
      end
    end
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------
  
  def establish_session_handler
    if params[:server_url].present?
      session[:wakeupsession] = "ok" # using session hash prompts rails session to load
      SessionHandler.establish(session.id, params[:server_url])
    else
      err = "Please enter a FHIR server address."
      redirect_to root_path, flash: { error: err }
    end
  end

end
