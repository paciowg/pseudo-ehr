################################################################################
#
# Advance Directives Controller
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class AdvanceDirectivesController < ApplicationController

  respond_to :pdf

  before_action :setup_fhir_client  # Make sure we're connected to the server

  #-----------------------------------------------------------------------------

  def index
    fhir_patient = @fhir_client.search(FHIR::Patient, 
                                        search: {
                                          parameters: {
                                            given: 'Betsy', 
                                            family: 'Smith-Johnson',
                                            birthdate: '1950-11-01'
                                          }
                                        }
                                      ).resource.entry.first.resource

    @patient = Patient.new(fhir_patient, @fhir_client)

    fhir_document_refs = @fhir_client.search(FHIR::DocumentReference, 
                                        search: {
                                          parameters: {
                                            patient: @patient.id,
                                            status: 'current'
                                          }
                                        }
                                      ).resource.entry

    @documents = []
    fhir_document_refs.each do |fhir_document_ref|
      @documents << DocumentReference.new(fhir_document_ref.resource)
    end
  end

  #-----------------------------------------------------------------------------

  def show
    attachment = @fhir_client.read(FHIR::Binary, params[:id]).response
    json = JSON.parse(attachment[:body])
    xml = Base64.decode64(json['data'])
    hash = Hash.from_xml(xml)

    document = hash["ClinicalDocument"]
    content = Base64.decode64(document["component"]["nonXMLBody"]["text"])
    send_data(content, filename: "#{document["title"]}.pdf", type: :pdf,
                      disposition: :inline)
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------

  def setup_fhir_client
    @fhir_client ||= FHIR::Client.new(ADI_SERVER)
  end

end
