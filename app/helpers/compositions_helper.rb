################################################################################
#
# Compositions Helper
#
# Copyright (c) 2023 The MITRE Corporation.  All rights reserved.
#
################################################################################

module CompositionsHelper
  # ADI PMO Initial Treatment ServiceRequest
  def loinc_polst_initial_tx_vs
    [
      {code: "LA33473-2", display: "Full Treatments"},
      {code: "LA33474-0", display: "Selective Treatments"},
      {code: "LA33475-7", display: "Comfort-focused Treatments"}
    ]
  end

  # ADI PMO Cardiopulmonary Resuscitation ServiceRequest
  def loinc_polst_cpr_vs
    [
      {code: "LA33470-8", display: "Yes CPR"},
      {code: "LA33471-6", display: "No CPR: Do Not Attempt Resuscitation"}
    ]
  end

  # ADI PMO Medically Assisted Nutrition ServiceRequest
  def loinc_polst_med_assist_nutr_vs
    [
      {code: "LA33489-8", display: "Provide feeding through new or existing surgically-placed tubes"},
      {code: "LA33490-6", display: "Trial period for artificial nutrition but no surgically-placed tubes"},
      {code: "LA33491-4", display: "No artificial means of nutrition desired"},
      {code: "LA33492-2", display: "Not discussed or no decision made (provide standard of care)"}
    ]
  end

  # ADI PMO Review Observation code
  def loinc_polst_review_vs
    [
      {code: "LA33476-5", display: "Yes the document was reviewed"},
      {code: "LA33478-1", display: "Conflict exists, notified patient"},
      {code: "LA33479-9", display: "Advance directive not available"},
      {code: "LA33481-5", display: "No advance directive exists"}
    ]
  end

  # ADI PMO Participant Observation
  def loinc_polst_discuss_part_vs
    [
      {code: "LA33482-3", display: "Patient with decision-making capacity"},
      {code: "LA33483-1", display: "Court appointed guardian"},
      {code: "LA33485-6", display: "Parent of minor"},
      {code: "LA33487-2", display: "Legal surrogate/health care agent"}
    ]
  end
end
