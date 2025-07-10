class PfeCategoryCodeDetector
  MAPPING_PATH = Rails.root.join('config/pfe_domain_mapping.yml')
  CACHE_PATH = Rails.root.join('tmp/pfe_domain_embeddings.yml')
  TEXT_MATCH_CACHE_PATH = Rails.root.join('tmp/pfe_text_match_cache.yml')
  OPENAI_MODEL = 'text-embedding-3-small'.freeze
  US_CORE_CACHE_PATH = Rails.root.join('tmp/us_core_category_cache.yml')

  US_CORE_CATEGORY_CODES = {
    'functional-status' => {
      display: 'Functional Status',
      definition: 'Observations related to a person’s functional capabilities such as mobility, self-care, and daily living activities.'
    },
    'cognitive-status' => {
      display: 'Cognitive Status',
      definition: 'Observations related to cognitive functions such as memory, orientation, attention, and decision-making.'
    }
  }.freeze

  class << self
    def detect_domain(candidate_text)
      candidate_text = candidate_text.to_s.strip
      return unknown_result if candidate_text.blank?

      text_cache = load_text_match_cache
      return text_cache[candidate_text] if text_cache[candidate_text]

      input_embedding = embed(candidate_text)
      domain_embeddings = load_or_generate_embeddings

      best_match_code, best_match_data = domain_embeddings.max_by do |_code, data|
        cosine_similarity(input_embedding, data[:embedding])
      end

      result = if best_match_code && best_match_data
                 {
                   code: best_match_code,
                   display: best_match_data[:display]
                 }
               else
                 unknown_result
               end

      # Update cache
      text_cache[candidate_text] = result
      File.write(TEXT_MATCH_CACHE_PATH, text_cache.to_yaml)

      result
    rescue StandardError => e
      Rails.logger.error("PFE domain detection failed: #{e.message}")
      unknown_result
    end

    def detect_us_core_category(candidate_text)
      candidate_text = candidate_text.to_s.strip
      return default_us_core_result if candidate_text.blank?

      cache = load_us_core_cache
      return cache[candidate_text] if cache.key?(candidate_text)

      input_embedding = embed(candidate_text)
      best_match_code, best_match_data = US_CORE_CATEGORY_CODES.max_by do |_code, data|
        domain_embedding = embed("#{data[:display]}. #{data[:definition]}")
        cosine_similarity(input_embedding, domain_embedding)
      end

      result = if best_match_code && best_match_data
                 { code: best_match_code, display: best_match_data[:display] }
               else
                 default_us_core_result
               end

      cache[candidate_text] = result
      File.write(US_CORE_CACHE_PATH, cache.to_yaml)
      result
    rescue StandardError => e
      Rails.logger.error("US Core category detection failed: #{e.message}")
      default_us_core_result
    end

    private

    def default_us_core_result
      { code: 'functional-status', display: 'Functional Status' }
    end

    def load_us_core_cache
      File.exist?(US_CORE_CACHE_PATH) ? YAML.load_file(US_CORE_CACHE_PATH) : {}
    end

    def unknown_result
      { code: 'unknown', display: 'Unknown' }
    end

    def embed(text)
      client = OpenAI::Client.new
      response = client.embeddings(
        parameters: {
          model: OPENAI_MODEL,
          input: text
        }
      )
      response.dig('data', 0, 'embedding') || []
    end

    def load_text_match_cache
      File.exist?(TEXT_MATCH_CACHE_PATH) ? YAML.load_file(TEXT_MATCH_CACHE_PATH) : {}
    end

    def cosine_similarity(v1, v2) # rubocop:disable Naming/MethodParameterName
      dot_product = v1.zip(v2).map { |a, b| a * b }.sum
      magnitude = ->(v) { Math.sqrt(v.map { |x| x**2 }.sum) }

      return 0.0 if v1.empty? || v2.empty?

      dot_product / (magnitude.call(v1) * magnitude.call(v2))
    end

    def load_or_generate_embeddings
      return YAML.load_file(CACHE_PATH) if File.exist?(CACHE_PATH)

      mapping = YAML.load_file(MAPPING_PATH)
      embeddings = {}

      mapping.each do |code, data|
        text = [data['display'], data['definition']].compact.join('. ')

        embeddings[code] = {
          embedding: embed(text),
          display: data['display'],
          definition: data['definition']
        }
        sleep(0.3) # To respect OpenAI rate limits
      end

      File.write(CACHE_PATH, embeddings.to_yaml)
      embeddings
    end
  end
end
