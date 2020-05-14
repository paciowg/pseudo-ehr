################################################################################
#
# Practitioner_role Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class PractitionerRole < Resource

    include ActiveModel::Model
  
    attr_reader :id, :code
  
    #-----------------------------------------------------------------------------
  
    def initialize(fhir_practitioner)
      @id             = fhir_practitioner.id
      @code   = fhir_practitioner.code
    end
  
end
