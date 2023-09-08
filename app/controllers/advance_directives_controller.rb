# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# app/controllers/adis_controller.rb
class AdvanceDirectivesController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/advance_directives
  def index
    @adis = fetch_and_cache_adis(params[:patient_id])
    flash.now[:notice] = 'No ADI found' if @adis.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @adis = []
  end

  # GET /advance_directives/:id
  def show
    @adi = fetch_and_cache_adi(params[:id])
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to :index, patient_id: @patient.id
  end

  private

  def fetch_and_cache_adis(patient_id)
    Rails.cache.fetch(cache_key_for_patient_adis(patient_id), expires_in: 5.minutes) do
      response = fetch_adi_documents_by_patient(patient_id)
      doc_entries = response.resource.entry.map(&:resource)

      adis = doc_entries.map do |doc|
        pdf = get_pdf_from_contents(doc.content)
        attachment_bundle_entries = get_structured_data_from_contents(doc.content)
        compositions = build_compositions(attachment_bundle_entries)
        AdvanceDirective.new(doc, compositions, pdf)
      end
      Rails.logger.debug adis.first
      adis.group_by(&:type)
    rescue StandardError => e
      raise "Error fetching patient's (#{patient_id}) ADIs from FHIR server. Status code: #{e.message}"
    end
  end

  def fetch_and_cache_adi(adi_id)
    patient_id = @patient.id
    Rails.cache.fetch(cache_key_for_adi(adi_id), expires_in: 5.minutes) do
      adis = fetch_and_cache_adis(patient_id)&.values&.flatten
      adi = adis&.find do |a|
        a.id == adi_id
      end
      raise "Unable to fetch ADI with id #{adi_id} from FHIR server." if adi.nil?

      adi
    rescue StandardError
      raise "Unable to fetch ADI with id #{adi_id} from FHIR server."
    end
  end

  def build_compositions(attachment_bundle_entries)
    fhir_compositions = attachment_bundle_entries.select { |entry| entry.resourceType == 'Composition' }
    fhir_compositions.map { |composition| Composition.new(composition, attachment_bundle_entries) }
  end

  def fetch_adi_documents_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      category: '75320-2'
    } }
    response = @client.search(FHIR::DocumentReference, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
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

  def get_pdf_from_contents(contents)
    pdf = nil
    pdf_content = contents.find { |content| check_content_attachment_resource(content) == 'pdf' }
    if pdf_content
      ref = pdf_content.attachment&.url
      binary_id = extract_id_from_ref(ref)
      pdf = retrieve_bundle_from_binary(binary_id, 'pdf')
    end
    pdf
  end

  def retrieve_bundle_from_binary(binary_id, content_type)
    attachment = @client.read(FHIR::Binary, binary_id)
    return attachment.resource.data if content_type == 'pdf'

    fhir_attachment_json = JSON(Base64.decode64(attachment.resource.data))
    fhir_attachment_bundle = FHIR::Bundle.new(fhir_attachment_json)
    fhir_attachment_bundle.entry.map(&:resource)
  rescue StandardError
    raise "#{attachment&.response&.dig(:code)} : Failed to fetch ADI FHIR Binary"
  end

  def fetch_bundle_from_contents(bundle_id)
    response = @client.read(FHIR::Bundle, bundle_id)
    response.resource.entry.map(&:resource)
  rescue StandardError
    raise "#{response&.response&.dig(:code)}: Failed to fetch ADI FHIR Bundle"
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

  def extract_id_from_ref(ref)
    ref&.split('/')&.last
  end

  def cache_key_for_patient_adis(patient_id)
    "patient_#{patient_id}_adis_#{session_id}"
  end

  def cache_key_for_adi(adi_id)
    "adi_#{adi_id}_#{session_id}"
  end
end
# rubocop:enable Metrics/ClassLength
