################################################################################
#
# eLTSS Claim Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Claim < Resource

  include ActiveModel::Model

  attr_reader :id, :status, :type, :use, :patient, :productOrService,
                :provider, :priority, :insurance

  def initialize(fhir_claim_eltss)
    @id                 = fhir_claim_eltss.id
    @status             = fhir_claim_eltss.status
    @type               = fhir_claim_eltss.type
    @use                = fhir_claim_eltss.use
    @patient            = fhir_claim_eltss.patient
    @productOrService   = fhir_claim_eltss.productOrService
    @provider           = fhir_claim_eltss.provider
    @priority           = fhir_claim_eltss.priority
    @insurance          = fhir_claim_eltss.insurance # THis may need to be split into 2 or otherwise specially handled
  end

end
