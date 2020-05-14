################################################################################
#
# RelatedPerson Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################


class RelatedPerson < Resource
    include ActiveModel::Model

    attr_reader :id, :patient, :relationship, :name, :resourceType

    def initialize(fhir_relatedPerson, fhir_client=nil)
        @id = fhir_relatedPerson.id
        @patient = fhir_relatedPerson.patient
        @relationship = fhir_relatedPerson.relationship
        @name = fhir_relatedPerson.name
        @resourceType = fhir_relatedPerson.resourceType
    end
end
