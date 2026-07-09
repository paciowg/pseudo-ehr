class QuestionnaireResponseProcessor
  Result = Struct.new(:success?, :bundle, :error, :code, :resource, keyword_init: true)

  def initialize(questionnaire_response_hash, fhir_server:)
    @questionnaire_response_hash = questionnaire_response_hash.deep_symbolize_keys
    @fhir_server = fhir_server
    @client = FhirClientService.new(fhir_server:).client
  end

  def call(submit: true)
    qr = build_questionnaire_response

    @client.begin_transaction

    # Historically pseudo-ehr has written the QuestionnaireResponse to the server along with the observations
    # generated from the QuestionnaireResponse; because in the typical use case the QuestionnaireResponse is
    # already present on the server we don't need to rewrite it, so we skip this step due to a bug in
    # fhir_models when hydrating a QuestionnaireResponse with contained resources

    # @client.add_transaction_request('PUT', "QuestionnaireResponse/#{qr.id}", qr)

    observations = PfeObservationBuilder.new(qr, questionnaire).build

    observations.each do |obs|
      @client.add_transaction_request('PUT', "Observation/#{obs.id}", obs)
    end

    if submit
      submit_transaction
    else
      # “Build-only” mode: hand the bundle back for later submission
      Result.new(success?: true, bundle: @client.transaction_bundle)
    end
  rescue StandardError => e
    Result.new(success?: false, error: e.message)
  end

  def submit_transaction
    reply = @client.end_transaction
    if reply.code.to_i < 400
      Result.new(success?: true, code: reply.code, resource: reply.resource)
    else
      Result.new(success?: false, code: reply.code, error: reply.try(:error), resource: reply.resource)
    end
  rescue StandardError => e
    Result.new(success?: false, error: e.message)
  end

  class << self
    def questionnaire_by_url
      @questionnaire_by_url ||= {}
    end
  end

  private

  def build_questionnaire_response
    FHIR::QuestionnaireResponse.new(@questionnaire_response_hash)
  end

  def questionnaire
    # Get the URL for retrieving the questionnaire from the response
    canonical = @questionnaire_response_hash[:questionnaire]
    url, version = canonical.to_s.split('|')

    # We don't need to get the history version at this time
    # url += "/_history/#{version}" if version

    # Return a cached version if we've already retrieved it
    return self.class.questionnaire_by_url[url] if self.class.questionnaire_by_url[url]

    if url.blank?
      raise 'No Questionnaire URL found in QuestionnaireResponse'
    end

    begin
      response = RestClient.get(url)
      self.class.questionnaire_by_url[url] = FHIR.from_contents(response.body)
    rescue RestClient::ExceptionWithResponse => e
      # Workaround: if the questionnaire is not available from the URL in the questionnaire response we also
      # want to look on the FHIR server we're connected to
      tail_match = url.match(%r{/Questionnaire/[A-Za-z0-9\-\._/]*})
      tail = tail_match[0] if tail_match
      raise "Failed to fetch Questionnaire from #{url}: #{e.response || e.message}" unless tail

      # Validate the tail of the Questionnaire URL to ensure it's a valid path
      raise 'Invalid Questionnaire path' if tail.include?('?') || tail.include?('#') || tail.include?('..')

      # Constrain @fhir_server to a limited whitelist of known servers
      allowed_servers = FhirServer.pluck(:base_url)
      raise 'Invalid FHIR server provided to QuestionnaireResponseProcessor' unless allowed_servers.include?(@fhir_server)

      # Validate URI of the FHIR server
      begin
        fhir_server_uri = URI.parse(@fhir_server.to_s)
      rescue URI::InvalidURIError
        raise 'Invalid FHIR server provided to QuestionnaireResponseProcessor'
      end

      unless %w[http https].include?(fhir_server_uri.scheme)
        raise 'Invalid FHIR server provided to QuestionnaireResponseProcessor'
      end

      # Build alternate_url with validated FHIR server URI plus validated tail
      alternate_url = fhir_server_uri.to_s.chomp('/') + tail

      raise "Failed to fetch Questionnaire from #{url}: #{e.response || e.message}" unless alternate_url

      begin
        response = RestClient.get(alternate_url)
        self.class.questionnaire_by_url[url] = FHIR.from_contents(response.body)
      rescue RestClient::ExceptionWithResponse => e2
        raise "Failed to fetch Questionnaire from #{url} or #{alternate_url}: #{e2.response || e2.message}"
      rescue RestClient::Exception, StandardError => e2
        raise "Unexpected error fetching Questionnaire from #{alternate_url}: #{e2.message}"
      end
    rescue RestClient::Exception, StandardError => e
      raise "Unexpected error fetching Questionnaire from #{url}: #{e.message}"
    end

    self.class.questionnaire_by_url[url]
  end
end
