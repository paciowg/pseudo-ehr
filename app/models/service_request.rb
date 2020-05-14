################################################################################
#
# eLTSS ServiceRequest Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################


class ServiceRequest < Resource
    include ActiveModel::Model

    attr_reader :id, :status, :intent, :occurrence, :quantity, :performer, :code

    def initialize(fhir_serviceRequest)
        @id = fhir_serviceRequest.id
        @status = fhir_serviceRequest.status
        @intent = fhir_serviceRequest.intent
        @occurrence = fhir_serviceRequest.occurrence
        @quantity = fhir_serviceRequest.quantity
        @performer = fhir_serviceRequest.performer
        @code = fhir_serviceRequest.code
    end

end
