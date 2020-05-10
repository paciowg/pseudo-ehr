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
    @text         = fhir_medication.text
    @status       = fhir_medication.status
    @ingredients  = fhir_medication.ingredient
  end

  #-----------------------------------------------------------------------------

  def codings
    @ingredients.map { |ingredient| ingredient.itemCodeableConcept.coding }
  end

end
