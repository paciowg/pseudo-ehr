################################################################################
#
# Medication Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Medication < Resource

	include ActiveModel::Model

  attr_reader :id, :text, :status, :ingredients

  #-----------------------------------------------------------------------------

  def initialize(fhir_medication)
  	@id 					= fhir_medication.id
    @language     = fhir_medication.language
    @text         = fhir_medication.text
    @contained    = fhir_medication.contained
    @identifier   = fhir_medication.identifier
    @code         = fhir_medication.code
    @status       = fhir_medication.status
    @manufacturer = fhir_medication.manufacturer
    @form         = fhir_medication.form
    @amount       = fhir_medication.amount
    @ingredients  = fhir_medication.ingredient
    @batch        = fhir_medication.batch
  end

  #-----------------------------------------------------------------------------

  def codings
    @code.coding
  end

end
