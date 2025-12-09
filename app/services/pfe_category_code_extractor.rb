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

  COLLECTION_DOMAIN_MAP = {
    'd4' => %w[89398-2 89394-1 85927-2 89392-5 89414-7 89390-9 101325-9 89412-1 89385-9 89381-8 89379-2
                        89416-2 89418-8 89402-2 95738-1],
    'd5' => %w[95018-8 95017-0 95015-4 95014-7 89387-5 95013-9 89406-3 45606-1],
    'b5' => %w[86677-2],
    'd3' => %w[95737-3 54602-8],
    'b1' => %w[70184-7 70185-4 70187-0 70189-6 70190-4 70191-2 70192-0 70193-8 70195-3],
    'b152' => %w[ask_more enough_time stressed embarrassed angry afraid_future strained 44250-9 44255-8 4259-0
                 44254-1 44251-7 44258-2 44252-5 44253-3 44260-8 69722-7 14372 44261-6],
    'b144' => %w[52731-7 54510-3 52732-5 54609-3 52493-4 52735-8 52736-6 52737-4 54614-3]
  }.freeze

  class << self
    # NOTE: The origininal implementation used the linkId for mapping QuestionnaireResponse answers to PFE
    # domains; the implementation has been updated to more appropriately use the code from the Questionnaire
    # to find the PFE domain but also keep the linkId lookup for backwards compatibility
    def extract(code, link_id=nil)
      link_id = link_id.to_s.delete_prefix('/')
      category_mapping = load_pfe_category_mapping
      extracted_categories = category_mapping[code].presence || category_mapping[link_id].presence || {}
      category_slice(extracted_categories)
    end

    def collection_category_slice(members)
      all_cat = members&.flat_map(&:code)&.flat_map(&:coding)&.map(&:code)&.uniq.presence || []
      domain_code = COLLECTION_DOMAIN_MAP.max_by { |_, items| (items & all_cat).size }&.first

      us_core_code = members&.flat_map(&:category)
                            &.flat_map(&:coding)
                            &.select { |c| c.system == US_CORE_CATEGORY_URL }
                            &.map(&:code)&.group_by(&:itself)&.transform_values(&:size)
                            &.max_by { |_, count| count }&.first

      extracted_categories = { 'us_core_category' => us_core_code, 'pfe_domain_icf_code' => domain_code }

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
      categories << us_core_categories(extracted_categories['us_core_category'])
      categories << domain_categories(extracted_categories['pfe_domain_icf_code'])

      categories.flatten
    end

    def us_core_categories(code)
      codes = Array(code) # Handle either an array or single code
      codes.flatten.map do |code|
        code = 'functional-status' if code.blank?
        FHIR::CodeableConcept.new(coding: [
                                    { system: US_CORE_CATEGORY_URL,
                                      code:,
                                      display: US_CORE_CATEGORY_CODES[code] }
                                  ])
      end
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
