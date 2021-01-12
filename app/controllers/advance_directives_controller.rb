################################################################################
#
# Advance Directives Controller
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class AdvanceDirectivesController < ApplicationController

  before_action :setup_fhir_client  # Make sure we're connected to the server

  #-----------------------------------------------------------------------------

  def index
    # fhir_patient = @fhir_client.search(FHIR::Patient, 
    #                                     search: {
    #                                       parameters: {
    #                                         given: 'Betsy', 
    #                                         family: 'Smith-Johnson',
    #                                         birthdate: '1950-11-07'
    #                                       }
    #                                     }
    #                                   ).resource

    # fhir_patient = get_resource("https://qa-rr-fhir.maxmddirect.com/Patient?given=Betsy&family=Smith-Johnson&birthdate=1950-11-07")
    # @patient = Patient.new(fhir_patient, @fhir_client)

    # @documents = get_resource("https://qa-rr-fhir.maxmddirect.com/DocumentReference?patient=ed8e82e7-8ad8-4825-b5f4-3a182aa967a5&status=current")
    # @documents = @fhir_client.search(FHIR::DocumentReference, 
    #                                   search: {
    #                                     parameters: {
    #                                       patient: patient.id
    #                                     }
    #                                   }
    #                                 )

    @binary = get_resource("https://qa-rr-fhir.maxmddirect.com/Binary/4cac07b9-99a1-4f7f-86cc-ecde72901d61")
    
    foo = 0
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------

  def setup_fhir_client
    @fhir_client ||= FHIR::Client.new(ADI_SERVER)
  end

  #-------------------------------------------------------------------------

  def get_resource(url)
    response = RestClient.get(url)
    byebug
    JSON.parse(response.body)
  end

end
