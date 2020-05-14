################################################################################
#
# eLTSS Contract Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################


class Contract < Resource
    include ActiveModel::Model

    attr_reader :id, :signer, :resourceType

    def initialize(fhir_contract)
        @id = fhir_contract.id
        @signer = fhir_contract.signer
        @resourceType = fhir_contract.resourceType
    end
end
