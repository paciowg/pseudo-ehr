################################################################################
#
# Medication Statement Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class MedicationStatement < Resource

	include ActiveModel::Model

  attr_reader :id, :part_of, :status, :medication, :subject, :effective, 
                :date_asserted, :information_source, :derived_from, :reason_code,
                :reason_reference, :note, :dosage 

  #-----------------------------------------------------------------------------

  def initialize(fhir_medication_statement, fhir_client)
  	@id 					        = fhir_medication_statement.id
    @part_of              = fhir_medication_statement.partOf
    @status               = fhir_medication_statement.status
    @medication           = medication(fhir_medication_statement, fhir_client)
    @subject              = fhir_medication_statement.subject
    @effective_datetime   = fhir_medication_statement.effectiveDateTime.to_date
    @date_asserted        = fhir_medication_statement.dateAsserted.to_date
    @information_source   = fhir_medication_statement.informationSource
    @derived_from         = fhir_medication_statement.derivedFrom
    @reason_code          = fhir_medication_statement.reasonCode
    @reason_reference     = fhir_medication_statement.reasonReference
    @note                 = fhir_medication_statement.note
    @dosage               = fhir_medication_statement.dosage

    @fhir_client          = fhir_client
  end

  #-----------------------------------------------------------------------------

  def medication(fhir_medication_statement, fhir_client)
    medication = fhir_client.read(FHIR::Medication, 
                          fhir_medication_statement.medicationReference.reference).resource
    Medication.new(medication)
  end

end
