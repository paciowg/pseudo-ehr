################################################################################
#
# Assessments Controller
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class AssessmentsController < ApplicationController

	def index
    @assessments = ASSESSMENTS
	end

  #-----------------------------------------------------------------------------

  def create
    redirect_to assessments_path, notice: 'Assessment was successfully submitted.'
  end

  #-----------------------------------------------------------------------------

  ASSESSMENTS = [
      { 
        name: "Hospital admission: Mobility", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-Hospital-Admission-Mobility-1.json" 
      },
      { 
        name: "Hospital admission: Self-care", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-Hospital-Admission-Mobility-SelfCare-1.json" 
      },
      { 
        name: "Hospital admission: Discharge mobility goals", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-Hospital-DischargeGoal-Mobility-1.json" 
      },
      { 
        name: "Hospital discharge: Mobility", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-Hospital-Discharge-Mobility-1.json" 
      },
      { 
        name: "Hospital discharge: Self-care", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-Hospital-Discharge-Mobility-SelfCare-1.json" 
      },
      { 
        name: "SNF admission: Mobility", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-SNF-Admission-Mobility-1.json" 
      },
      { 
        name: "SNF admission: Self-care", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-SNF-Admission-Mobility-SelfCare-1.json" 
      },
      { 
        name: "SNF admission: Discharge mobility goals", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-SNF-DischargeGoal-Mobility-1.json" 
      },
      { 
        name: "SNF admission: Discharge self-care goals", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-SNF-DischargeGoal-Mobility-SelfCare-1.json" 
      },
      { 
        name: "SNF discharge: Mobility", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-SNF-Discharge-Mobility-1.json" 
      },
      { 
        name: "SNF discharge: Self-care" , 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-SNF-Discharge-Mobility-SelfCare-1.json" 
      },
      { 
        name: "HHA start of care: Mobility", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-HH-StartOfCare-Mobility-1.json" 
      },
      { 
        name: "HHA start of care: Self-care", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-HH-StartOfCare-Mobility-SelfCare-1.json" 
      },
      { 
        name: "HHA discharge: Mobility", 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-HH-Discharge-Mobility-1.json" 
      },
      { 
        name: "HHA discharge: Self-care" , 
        file: "assessments/QuestionnaireResponse-SDC-QResponse-HH-Discharge-Mobility-SelfCare-1.json" 
      }
    ]

end
