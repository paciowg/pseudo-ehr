class PfeCategoryCodeExtractor
  PFE_DOMAIN_PATH = Rails.root.join('config/pfe_domain_mapping.yml')
  PFE_CATEGORY_MAPPING_PATH = Rails.root.join('config/qr_linkid_to_pfe_category_mapping.yml')
  US_CORE_CATEGORY_URL = 'http://hl7.org/fhir/us/core/CodeSystem/us-core-category'.freeze
  PFE_DOMAIN_CATEGORY_URL = 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-category-cs'.freeze
  SURVEY_CATEGORY_URL = 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-survey-category-cs'.freeze

  US_CORE_CATEGORY_CODES = {
    'functional-status' => 'Functional Status',
    'cognitive-status' => 'Cognitive Status'
  }.freeze

  class << self
    def extract(link_id)
      link_id = link_id.to_s.delete_prefix('/')
      category_mapping = load_pfe_category_mapping

      extracted_categories = category_mapping[link_id].presence || {}
      category_slice(extracted_categories)
    end

    private

    def load_pfe_domain
      File.exist?(PFE_DOMAIN_PATH) ? YAML.load_file(PFE_DOMAIN_PATH) : {}
    end

    def load_pfe_category_mapping
      File.exist?(PFE_CATEGORY_MAPPING_PATH) ? YAML.load_file(PFE_CATEGORY_MAPPING_PATH) : {}
    end

    def category_slice(extracted_categories)
      categories = [
        FHIR::CodeableConcept.new(coding: [
                                    { system: SURVEY_CATEGORY_URL, code: 'survey' }
                                  ])
      ]
      categories << us_core_category(extracted_categories['us_core_category'])
      categories << domain_categories(extracted_categories['pfe_domain_icf_code'])

      categories.flatten
    end

    def us_core_category(code)
      code = 'functional-status' if code.blank?
      FHIR::CodeableConcept.new(coding: [
                                  { system: US_CORE_CATEGORY_URL,
                                    code:,
                                    display: US_CORE_CATEGORY_CODES[code] }
                                ])
    end

    def domain_categories(codes)
      domains = load_pfe_domain
      [codes].flatten.map do |code|
        code = 'unknown' if code.blank?
        FHIR::CodeableConcept.new(coding: [
                                    {
                                      system: PFE_DOMAIN_CATEGORY_URL,
                                      code:,
                                      display: domains.dig(code, 'display')
                                    }
                                  ])
      end
    end
  end
end
