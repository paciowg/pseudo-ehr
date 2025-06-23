module ResourceFetchHelper
  TIMEOUT_ERROR_MESSAGE = 'Unable to fetch resources: Request timed out.'.freeze
  CLIENT_BUNDLE_METHODS = %i[search read_feed].freeze
  DEFAULT_MAX_RESULTS = 300
  DEFAULT_SORT = '-_lastUpdated'.freeze
  NON_PATIENT_RELATED_RESOURCES = %i[Organization Location PractitionerRole].freeze
  PATIENT_RELATED_RESOURCES = %i[
    ServiceRequest NutritionOrder Observation CareTeam Goal QuestionnaireResponse Condition
    List Composition MedicationRequest Procedure DiagnosticReport DocumentReference
  ].freeze

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
              (CLIENT_BUNDLE_METHODS.exclude?(method) && response.resource.is_a?(resource_class))

    return response if success

    raise "Error fetching #{resource_class.name}:\n #{response.resource&.inspect}"
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TIMEOUT_ERROR_MESSAGE
  end

  def fetch_resource_with_defaults(resource_class, max_results = DEFAULT_MAX_RESULTS, additional_params = {})
    parameters = {
      _sort: DEFAULT_SORT,
      _count: max_results / 2
    }.merge(additional_params)

    response = fetch_resource(resource_class, method: :search, parameters:)
    fetch_bundle_entries(response, max_results)
  end

  def fetch_patient_related(resource_class, patient_id, max_results = DEFAULT_MAX_RESULTS, since_time = nil)
    parameters = { patient: patient_id, _include: '*' }
    parameters[:_since] = since_time.iso8601 if since_time
    fetch_resource_with_defaults(resource_class, max_results, parameters)
  end

  # Dynamically generate non-patient-related fetch methods
  NON_PATIENT_RELATED_RESOURCES.each do |resource_class_name|
    method_name = "fetch_#{resource_class_name.to_s.underscore.pluralize}"
    define_method(method_name.to_sym) do |max_results = DEFAULT_MAX_RESULTS, since_time = nil|
      additional_params = resource_class_name == :PractitionerRole ? { _include: '*' } : {}
      additional_params[:_since] = since_time.iso8601 if since_time
      fetch_resource_with_defaults("FHIR::#{resource_class_name}".constantize, max_results, additional_params)
    end
  end

  # Dynamically generate methods for patient-related resources
  PATIENT_RELATED_RESOURCES.each do |resource_class_name|
    method_name = "fetch_#{resource_class_name.to_s.underscore.pluralize}_by_patient"
    define_method(method_name.to_sym) do |patient_id, max_results = DEFAULT_MAX_RESULTS, since_time = nil|
      fetch_patient_related("FHIR::#{resource_class_name}".constantize, patient_id, max_results, since_time)
    end
  end

  # Fetch specific patient data

  def fetch_patients_by_id
    parameters = { _id: params[:query_id] }
    fetch_resource_with_defaults(FHIR::Patient, 2, parameters)
  end

  def fetch_patients_by_name
    parameters = { name: params[:query_name], active: true }
    fetch_resource_with_defaults(FHIR::Patient, 20, parameters)
  end

  def fetch_single_patient(patient_id)
    fetch_resource(FHIR::Patient, method: :read, id: patient_id)&.resource
  end

  def fetch_patients
    if params[:query_id].present?
      fetch_patients_by_id
    elsif params[:query_name].present?
      fetch_patients_by_name
    elsif Patient.updated_at
      parameters = { _since: Patient.updated_at.iso8601, active: true }
      fetch_resource_with_defaults(FHIR::Patient, 500, parameters)
    else
      fetch_resource_with_defaults(FHIR::Patient, 500, { active: true })
    end
  end

  def fetch_single_patient_record(patient_id, max_results = 500, since_time = nil)
    search_params = {
      _sort: '-_lastUpdated', _maxresults: max_results, _count: max_results / 2,
      _include: '*', _revinclude: '*', '_include:iterate': '*'
    }

    # Add _since parameter if provided
    search_params[:_since] = since_time.iso8601 if since_time

    response = client.fetch_patient_record(patient_id, search_params:)
    add_query(response.request)

    fetch_bundle_entries(response, max_results)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TIMEOUT_ERROR_MESSAGE
  end

  def fetch_adi_documents_by_patient(patient_id, since_time = nil)
    status_map = { 'Superseded' => 'superseded', 'Current' => 'current' }
    status = status_map[params[:status]]
    parameters = { patient: patient_id, category: '42348-3,75320-2', _count: 100, status: }.compact
    parameters[:_since] = since_time.iso8601 if since_time

    fetch_resource_with_defaults(FHIR::DocumentReference, 100, parameters)
  end

  def fetch_toc_compositions_by_patient(patient_id, since_time = nil)
    parameters = { patient: patient_id, category: '18761-7', _count: 100 }.compact
    parameters[:_since] = since_time.iso8601 if since_time

    fetch_resource_with_defaults(FHIR::Composition, 100, parameters)
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

  def fetch_observation(observation_id)
    fetch_resource(FHIR::Observation, method: :read, id: observation_id)&.resource
  end

  def fetch_bundle_entries(response, max_results = 500)
    bundle_entries = []
    while response&.resource.is_a?(FHIR::Bundle) && response.resource.entry.present?
      bundle_entries.concat(response.resource.entry.map(&:resource))
      break if bundle_entries.size >= max_results

      response = client.next_page(response)
    end

    bundle_entries.compact.uniq
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TIMEOUT_ERROR_MESSAGE
  end
end
