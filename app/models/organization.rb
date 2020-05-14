################################################################################
#
# eLTSS Organization Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Organization < Resource
    include ActiveModel::Model

    attr_reader :id, :name, :resourceType
    def initialize(fhir_organization)
        @id = fhir_organization.id
        @name = fhir_organization.name
        @resourceType = fhir_organization.resourceType
    end
end
