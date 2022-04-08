################################################################################
#
# Consent Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Consent < Resource

  include ActiveModel::Model

  attr_reader :id, :status, :scope, :provision

  def initialize(fhir_consent, fhir_client=nil)
    @id                  = fhir_consent.id
    @status              = fhir_consent.status
    @scope               = fhir_consent.scope
    @provision           = fhir_consent.provision
  end

end
