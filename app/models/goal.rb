################################################################################
#
# eLTSS Goal Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Goal < Resource

  include ActiveModel::Model

  attr_reader :id, :description, :lifecycleStatus, :category, :priority
              :subject

  def initialize(fhir_goal)
    @id               = fhir_goal.id
    @description      = fhir_goal.description
    @lifecycleStatus  = fhir_goal.lifecycleStatus
    @category         = fhir_goal.category
    @priority         = fhir_goal.priority
    @subject          = fhir_goal.subject
  end

end
