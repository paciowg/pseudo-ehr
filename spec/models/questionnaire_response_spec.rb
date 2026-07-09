require 'rails_helper'

RSpec.describe QuestionnaireResponse do
  describe '#questionnaire_title' do
    it 'extracts the questionnaire id from a versioned canonical URL' do
      fhir_questionnaire_response = FHIR::QuestionnaireResponse.new(
        id: 'gad7-response',
        questionnaire: 'https://gw.interop.community/paciosandbox/open/Questionnaire/GAD7Questionnaire|0.1.0'
      )

      questionnaire_response = described_class.new(fhir_questionnaire_response)

      expect(questionnaire_response.questionnaire_title).to eq('GAD7Questionnaire')
    end

    it 'extracts the questionnaire id from an unversioned canonical URL' do
      fhir_questionnaire_response = FHIR::QuestionnaireResponse.new(
        id: 'gad7-response',
        questionnaire: 'https://gw.interop.community/paciosandbox/open/Questionnaire/GAD7Questionnaire'
      )

      questionnaire_response = described_class.new(fhir_questionnaire_response)

      expect(questionnaire_response.questionnaire_title).to eq('GAD7Questionnaire')
    end
  end
end
