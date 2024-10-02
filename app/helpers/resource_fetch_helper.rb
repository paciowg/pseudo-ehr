module ResourceFetchHelper # rubocop:disable Metrics/ModuleLength
  TIMEOUT_ERROR_MESSAGE = 'Unable to fetch resources: Request timed out.'.freeze
  CLIENT_BUNDLE_METHODS = %i[search read_feed].freeze

  def current_server
    @current_server ||= FhirServer.find_by(base_url: session[:fhir_server_url])
  end

  def client
    @client ||= FhirClientService.new(fhir_server: current_server).client
  end

  def queries
    session[:queries] ||= []
  end

  def add_query(request)
    return unless request

    queries << "#{request[:method].upcase} #{request[:url]}"
  end

  def clear_queries
    session[:queries] = []
  end

  def fetch_resource(resource_class, method:, parameters: {}, id: nil)
    response = case method
               when :search
                 client.search(resource_class, search: { parameters: })
               when :read
                 client.read(resource_class, id)
               when :read_feed
                 client.read_feed(resource_class)
               else
                 raise "Unsupported fetch method: #{method}"
               end

    add_query(response.request)

    success = (CLIENT_BUNDLE_METHODS.include?(method) && response.resource.is_a?(FHIR::Bundle)) ||
              (!CLIENT_BUNDLE_METHODS.include?(method) && response.resource.is_a?(resource_class))

    return response if success

    raise "Error fetching #{resource_class.name}:\n #{response.resource&.inspect}"
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TIMEOUT_ERROR_MESSAGE
  end

  def fetch_patients_by_id
    response = fetch_resource(FHIR::Patient, method: :search, parameters: { _id: params[:query_id] })
    fetch_bundle_entries(response)
  end

  def fetch_patients_by_name
    parameters = { name: params[:query_name], active: true, _sort: '-_lastUpdated' }
    response = fetch_resource(FHIR::Patient, method: :search, parameters:)
    fetch_bundle_entries(response)
  end

  def fetch_single_patient(patient_id)
    fetch_resource(FHIR::Patient, method: :read, id: patient_id)&.resource
  end

  def fetch_patients
    if params[:query_id].present?
      fetch_patients_by_id
    elsif params[:query_name].present?
      fetch_patients_by_name
    else
      fetch_resource(FHIR::Patient, method: :read_feed)&.resource&.entry&.map(&:resource)
    end
  end

  def fetch_single_patient_record(patient_id, max_results = 150)
    search_params = { _sort: '-_lastUpdated', _maxresults: max_results, _count: 50 }
    response = client.fetch_patient_record(patient_id, search_params:)
    add_query(response.request)

    fetch_bundle_entries(response, max_results)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TIMEOUT_ERROR_MESSAGE
  end

  def fetch_organizations
    response = fetch_resource(FHIR::Organization, method: :search, parameters: { _sort: '-_lastUpdated', _count: 50 })
    fetch_bundle_entries(response, 50)
  end

  def fetch_locations
    response = fetch_resource(FHIR::Location, method: :search, parameters: { _sort: '-_lastUpdated', _count: 50 })
    fetch_bundle_entries(response, 50)
  end

  def fetch_practitioner_roles
    parameters = { _sort: '-_lastUpdated', _include: '*', _count: 100 }
    response = fetch_resource(FHIR::PractitionerRole, method: :search, parameters:)
    fetch_bundle_entries(response, 300)
  end

  def fetch_adi_documents_by_patient(patient_id)
    status_map = { 'Superseded' => 'superseded', 'Current' => 'current' }
    status = status_map[params[:status]]
    parameters = { patient: patient_id, category: '42348-3,75320-2', _count: 100, status: }.compact

    response = fetch_resource(FHIR::DocumentReference, method: :search, parameters:)
    fetch_bundle_entries(response, 100)
  end

  def fetch_document_reference(doc_id)
    fetch_resource(FHIR::DocumentReference, method: :read, id: doc_id)&.resource
  end

  def fetch_binary(binary_id)
    fetch_resource(FHIR::Binary, method: :read, id: binary_id)&.resource
  end

  def fetch_bundle(bundle_id)
    fetch_resource(FHIR::Bundle, method: :read, id: bundle_id)&.resource
  end

  def fetch_bundle_entries(response, max_results = 150)
    bundle_entries = []
    while response&.resource.is_a?(FHIR::Bundle) && response.resource.entry.present?
      bundle_entries.concat(response.resource.entry.map(&:resource))
      break if bundle_entries.size >= max_results

      response = client.next_page(response)
    end

    raise "Error fetching Patient record:\n #{response.resource&.inspect}" if bundle_entries.empty?

    bundle_entries.compact.uniq
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TIMEOUT_ERROR_MESSAGE
  end
end
