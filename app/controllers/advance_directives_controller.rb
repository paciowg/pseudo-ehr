# app/controllers/adis_controller.rb
class AdvanceDirectivesController < ApplicationController
  include AdvanceDirectivesHelper
  before_action :require_server, :retrieve_patient, :set_resources_count
  # GET /patients/:patient_id/advance_directives
  def index
    @adis = get_adis(params[:patient_id])
    flash.now[:notice] = I18n.t('controllers.advance_directives.no_adi_found') if @adis.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @adis = []
  end

  # GET /advance_directives/:id
  def show
    @adi = get_adi(params[:id])
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patient_advance_directives_path, id: @patient.id
  end

  # TODO: to be reworked once we will implement selecting a provider when connecting to the server
  # We will use the logged provider data in the update request as opposed to the hardcoded provider.
  # PUT /advance_directives/:id
  def update_pmo
    @adi = get_adi(params[:id])
    doc_ref = @adi.fhir_doc_ref
    bundle_entries = get_structured_data_from_contents(doc_ref.content)

    bundle_entries.each do |resource|
      update_service_request(resource) if resource.resourceType == 'ServiceRequest'
      update_composition(resource) if resource.resourceType == 'Composition'
    end

    save_updated_data(bundle_entries, doc_ref)

    flash[:success] = I18n.t('controllers.advance_directives.pmo_updated')
    PatientRecordCache.patient_records_last_sync[@patient.id] = 2.hours.ago
    AdvanceDirective.updated_at(2.hours.ago)
    redirect_to patient_advance_directives_path, id: @patient.id
  rescue StandardError => e
    Rails.logger.debug { "Error updating PMO: #{e.message}" }
    flash[:error] = I18n.t('controllers.advance_directives.pmo_update_error')
    redirect_to advance_directive_path, id: params[:id]
  end

  # PUT /advance_directives/:id
  def revoke_living_will
    @adi = get_adi(params[:id])
    doc_ref = @adi.fhir_doc_ref
    doc_ref.extension ||= []
    doc_ref.extension << revoke_extension('cancelled')
    @client.update(doc_ref, doc_ref.id)

    flash[:success] = I18n.t('controllers.advance_directives.living_will_revoked')
    PatientRecordCache.patient_records_last_sync[@patient.id] = 2.hours.ago
    AdvanceDirective.updated_at(2.hours.ago)
    redirect_to patient_advance_directives_path, id: @patient.id
  rescue StandardError => e
    Rails.logger.debug { "Error revoking Living Will: #{e.message}" }
    flash[:error] = I18n.t('controllers.advance_directives.living_will_revoke_error')
    redirect_to advance_directive_path, id: params[:id]
  end

  private

  def revoke_extension(code)
    {
      url: 'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-document-revoke-status-extension',
      valueCoding: {
        system: 'http://hl7.org/fhir/us/pacio-adi/CodeSystem/ADIRevokeStatusCS',
        code:
      }
    }
  end

  def get_adis(patient_id)
    adis = filter_adis_by_status(patient_id)
    return adis.sort_by(&:date).reverse.group_by(&:identifier) unless AdvanceDirective.expired? || adis.blank?

    # First try to get document references from the patient record cache
    cached_doc_refs = cached_resources_type('DocumentReference')
    adi_entries = filter_doc_refs_or_compositions_by_category(cached_doc_refs, adi_category_codes)

    # Only fetch ADIs directly if not found in patient record
    if adi_entries.blank?
      Rails.logger.info('ADIs not found in patient record cache, fetching directly')
      adi_entries = fetch_adi_documents_by_patient(patient_id, AdvanceDirective.updated_at)
    end

    adi_entries.each do |doc|
      attachment_bundle_entries = get_structured_data_from_contents(doc.content) || []
      compositions = build_compositions(attachment_bundle_entries)
      AdvanceDirective.new(doc, compositions)
    end

    adis = filter_adis_by_status(patient_id)
    adis.sort_by(&:date).reverse.group_by(&:identifier)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing ADIs:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise 'Error fetching or parsing ADIs. Check logs for detail.'
  end

  def filter_adis_by_status(patient_id)
    adis = AdvanceDirective.filter_by_patient_id(patient_id)
    if adi_status
      adis.filter { |r| r.status == adi_status }
    else
      adis
    end
  end

  def get_adi(adi_id)
    adi = AdvanceDirective.find(adi_id)
    return adi if adi

    # Try to find the document in the cached resources first
    doc = find_cached_resource('DocumentReference', adi_id)

    # If not found in cache, fetch directly from the server
    unless doc
      Rails.logger.info("ADI #{adi_id} not found in cache, fetching directly")
      doc = fetch_document_reference(adi_id)
    end

    attachment_bundle_entries = get_structured_data_from_contents(doc.content) || []
    compositions = build_compositions(attachment_bundle_entries)
    AdvanceDirective.new(doc, compositions)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing patient ADI #{adi_id}:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Unable to fetch or parse ADI with id #{adi_id}. Check logs for detail"
  end

  def build_compositions(attachment_bundle_entries)
    fhir_compositions = attachment_bundle_entries.select { |entry| entry.resourceType == 'Composition' }
    fhir_compositions.map { |composition| Composition.new(composition, attachment_bundle_entries) }
  end

  def get_structured_data_from_contents(contents)
    bundle_content = contents.find { |content| check_content_attachment_resource(content) == 'bundle' }
    return fetch_bundle_from_contents(extract_id_from_attachment_url(bundle_content)) if bundle_content

    binary_content = contents.find { |content| check_content_attachment_resource(content) == 'binary' }
    retrieve_bundle_from_binary(extract_id_from_attachment_url(binary_content), 'json') if binary_content
  end

  def extract_id_from_attachment_url(content)
    content.attachment&.url&.split('/')&.last
  end

  def retrieve_bundle_from_binary(binary_id, content_type)
    begin
      # Try to find binary in cached resources first
      fhir_binary = find_cached_resource('Binary', binary_id)

      # If not found in cache, fetch directly
      if fhir_binary
        Rails.logger.info("Using cached Binary #{binary_id}")
      else
        Rails.logger.info("Binary #{binary_id} not found in cache, fetching directly")
        fhir_binary = fetch_binary(binary_id)
      end

      data = fhir_binary&.data

      return { pdf: data, pdf_binary_id: binary_id } if content_type == 'pdf'
    rescue StandardError => e
      Rails.logger.error "Failed to fetch ADI FHIR Binary:\n #{e.message.inspect}"
      return { pdf: nil, pdf_binary_id: binary_id } if content_type == 'pdf'
    end

    return if data.nil?

    begin
      fhir_attachment_json = JSON(Base64.decode64(data))
      fhir_attachment_bundle = FHIR::Bundle.new(fhir_attachment_json)
      fhir_attachment_bundle.entry.map(&:resource)
    rescue StandardError => e
      Rails.logger.error "Error parsing binary data: #{e.message.inspect}"
      Rails.logger.error "Binary type: #{fhir_binary&.contentType}"
      []
    end
  rescue StandardError => e
    Rails.logger.error "Error in retrieve_bundle_from_binary: #{e.message.inspect}"
    content_type == 'pdf' ? { pdf: nil, pdf_binary_id: binary_id } : []
  end

  def fetch_bundle_from_contents(bundle_id)
    fhir_bundle = find_cached_resource('Bundle', bundle_id)

    # If not found in cache, fetch directly
    if fhir_bundle.blank?
      Rails.logger.info("Bundle #{bundle_id} not found in cache, fetching directly")
      fhir_bundle = fetch_bundle(bundle_id)
    end

    fhir_bundle.entry.map(&:resource)
  rescue StandardError => e
    Rails.logger.error "Failed to fetch ADI FHIR Bundle #{bundle_id}:\n #{e.message.inspect}"
    raise "Failed to fetch ADI FHIR Bundle #{bundle_id}. Check logs for detail."
  end

  def check_content_attachment_resource(content)
    case content.attachment.contentType
    when 'application/pdf'
      'pdf'
    when 'application/fhir+json', 'application/json'
      return 'bundle' if content.attachment&.url&.include?('Bundle')

      'binary' if content.attachment&.url&.include?('Binary')
    end
  end

  def adi_status
    status_map = { 'Superseded' => 'superseded', 'Current' => 'current' }
    status_map[params[:status]]
  end

  def extract_id_from_ref(ref)
    ref&.split('/')&.last
  end

  # Update service request parameters
  def service_request_params
    params.require(:service_request).permit!
  end

  # Get Loinc code display
  def get_loinc_code_display(code)
    loinc_code_list = loinc_polst_med_assist_nutr_vs + loinc_polst_initial_tx_vs + loinc_polst_cpr_vs
    loinc_code_list.find { |loinc_code| loinc_code[:code] == code }&.dig(:display)
  end

  # ServiceRequest.code
  def set_service_request_code(code, text)
    {
      coding: [
        {
          system: 'http://loinc.org',
          code:,
          display: get_loinc_code_display(code)
        }
      ],
      text:
    }
  end

  # set DocumentReference.relatesTo
  def build_document_ref_relates_to(doc_ref)
    [
      {
        code: 'replaces',
        target: {
          reference: "DocumentReference/#{doc_ref.id}"
        }
      }
    ]
  end

  # set DocumentReference.content
  def set_document_ref_content(binary_id, bundle_id, pdf = nil)
    pdf_content = {
      attachment: {
        contentType: 'application/pdf',
        url: 'Binary/9101087d-583c-4164-8137-2dafa4dbceee'
      }
    }
    [
      {
        attachment: {
          contentType: 'application/json',
          url: "Binary/#{binary_id}"
        },
        format: {
          system: 'http://ihe.net/fhir/ValueSet/IHE.FormatCode.codesystem',
          code: 'urn:hl7-org:sdwg:ccda-on-fhir-json:1.0',
          display: 'FHIR Document Bundle'
        }
      },
      {
        attachment: {
          url: "Bundle/#{bundle_id}"
        },
        format: {
          system: 'http://ihe.net/fhir/ValueSet/IHE.FormatCode.codesystem',
          code: 'urn:hl7-org:sdwg:ccda-on-fhir-json:1.0',
          display: 'FHIR Document Bundle'
        }
      },
      pdf && pdf_content
    ].compact
  end

  def update_service_request(resource)
    case resource.category&.first&.coding&.first&.display
    when 'Additional portable medical orders or instructions'
      resource.code.text = service_request_params['Additional portable medical orders or instructions']['text']
      # rubocop:disable Layout/LineLength
    when 'Medically assisted nutrition orders', 'Initial portable medical treatment orders', 'Cardiopulmonary resuscitation orders'
      assign_service_request_code_for_resource(resource)
    end
    # rubocop:enable Layout/LineLength
  end

  def update_composition(resource)
    resource.date = current_time_formatted
    resource.attester.each { |attester| attester.time = current_time_formatted }
    resource.section.each do |section|
      next unless section.title == 'ePOLST Portable Medical Orders'

      update_section_entries(resource, section)
    end
  end

  def update_section_entries(_resource, section)
    section_entries = @adi.compositions.first.sections.select do |s|
      s['title'] == section.title
    end.pluck('objects').flatten
    section_entries.each do |object|
      text = service_request_params[object[:category]]['text'].to_s
      section.text&.div = section.text&.div&.gsub(object[:request_text].to_s, text)
    end
  end

  def assign_service_request_code_for_resource(resource)
    code = service_request_params[resource.category&.first&.coding&.first&.display]['code']
    text = service_request_params[resource.category&.first&.coding&.first&.display]['text']
    resource.code = set_service_request_code(code, text)
  end

  def current_time_formatted
    Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%:z')
  end

  def save_updated_data(bundle_entries, doc_ref, pdf = nil)
    new_entries = bundle_entries.map { |entry| { resource: entry } }
    # create new bundle
    new_bundle = FHIR::Bundle.new
    new_bundle.type = 'document'
    new_bundle.entry = new_entries
    new_bundle = @client.create(new_bundle).resource
    # create Binary resouce
    fhir_binary = FHIR::Binary.new(
      contentType: 'application/fhir+json',
      data: Base64.encode64(new_bundle.to_json)
    )
    fhir_binary = @client.create(fhir_binary).resource
    # create new DocumentReference
    new_doc_ref = doc_ref.dup
    new_doc_ref.status = 'current'
    new_doc_ref.description = "Betsy's Living Will NEW" if pdf
    new_doc_ref.date = current_time_formatted
    new_doc_ref.relatesTo = build_document_ref_relates_to(doc_ref)
    new_doc_ref.content = set_document_ref_content(fhir_binary.id, new_bundle.id, pdf)
    @client.create(new_doc_ref)
    # Update the old DocumentReference status to superseded
    doc_ref.status = 'superseded'
    @client.update(doc_ref, doc_ref.id)
  end
end
# rubocop:enable Metrics/ClassLength
