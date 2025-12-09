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
    @client.add_transaction_request('PUT', "QuestionnaireResponse/#{qr.id}", qr)

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
    url += "/_history/#{version}" if version

    # Return a cached version if we've already retrieved it
    return self.class.questionnaire_by_url[url] if self.class.questionnaire_by_url[url]

    if url.blank?
      raise "No Questionnaire URL found in QuestionnaireResponse"
    end

    begin
      response = RestClient.get(url)
      self.class.questionnaire_by_url[url] = FHIR.from_contents(response.body)
    rescue RestClient::ExceptionWithResponse => e
      # Workaround: if the questionnaire is not available from the URL in the questionnaire response we also
      # want to check the FHIR server we're connected to
      tail = url.match(/\/Questionnaire\/.+/)
      alternate_url = @fhir_server.to_s.chomp('/') + tail[0] if tail
      if alternate_url
        begin
          response = RestClient.get(alternate_url)
          self.class.questionnaire_by_url[url] = FHIR.from_contents(response.body)
        rescue RestClient::ExceptionWithResponse => e2
          raise "Failed to fetch Questionnaire from #{url} or #{alternate_url}: #{e2.response || e2.message}"
        rescue RestClient::Exception, StandardError => e2
          raise "Unexpected error fetching Questionnaire from #{alternate_url}: #{e2.message}"
        end
      else
        raise "Failed to fetch Questionnaire from #{url}: #{e.response || e.message}"
      end
    rescue RestClient::Exception, StandardError => e
      raise "Unexpected error fetching Questionnaire from #{url}: #{e.message}"
    end

    return self.class.questionnaire_by_url[url]
  end
end
