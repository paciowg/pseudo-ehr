class QuestionnaireResponseProcessor
  Result = Struct.new(:success?, :bundle, :error, :code, :resource, keyword_init: true)

  def initialize(questionnaire_response_hash, fhir_server:)
    @questionnaire_response_hash = questionnaire_response_hash.deep_symbolize_keys
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
    url = @questionnaire_response_hash[:questionnaire]

    # TODO: to be removed. none of the QR has a valid questionnaire url
    # this hack is to use a known url for QR BSJ1-QuestionnaireResponse-GlobalAlliant-01
    if url&.downcase&.include?('zbi')
      url = 'https://gw.interop.community/cmspqrs/open/Questionnaire/questionnaire-ZBI22'
    end

    self.class.questionnaire_by_url[url] ||= begin
      response = RestClient.get(url)
      FHIR.from_contents(response.body)
    rescue RestClient::ExceptionWithResponse => e
      raise "Failed to fetch Questionnaire from #{url}: #{e.response}"
    rescue RestClient::Exception, StandardError => e
      raise "Unexpected error fetching Questionnaire from #{url}: #{e.message}"
    end
  end
end
