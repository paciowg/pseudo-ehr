# frozen_string_literal: true

################################################################################
#
# Practitioner Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Practitioner < Resource

  include ActiveModel::Model

  attr_reader :id, :meta, :implicit_rules, :language, :text, :identifier,
                :active, :name, :telecoms, :addresses, :gender, :birthDate,
                :photo, :qualifications, :communications

  #-----------------------------------------------------------------------------

  def initialize(practitioner)
    @name             = practitioner.name
    @telecoms         = practitioner.telecom
    @addresses        = practitioner.address
    @gender           = practitioner.gender
    @birth_date       = practitioner.birthDate
    @photo            = practitioner.photo
    @qualifications   = practitioner.qualification
    @communications   = practitioner.communication
  end

end
