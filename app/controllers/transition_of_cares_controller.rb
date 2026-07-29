# app/controllers/transition_of_cares_controller.rb
class TransitionOfCaresController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/transition_of_cares
  def index
    @pagy, @tocs = pagy_array(fetch_tocs, items: 10)
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patients_path
  end

  # POST /patients/:patient_id/transition_of_cares
  def create
    begin
      composition_data = TransitionOfCareCompositionService.build(
        patient_id: patient_id,
        toc_params: params[:toc]
      )

      fhir_composition = create_resource(composition_data)

      if fhir_composition.present?
        PatientRecordCache.add_resource_to_patient_record(patient_id, fhir_composition)
        entries = retrieve_current_patient_resources
        Composition.new(fhir_composition, entries)
        flash[:success] = I18n.t('controllers.transition_of_cares.create_success')
      else
        flash[:danger] = I18n.t('controllers.transition_of_cares.create_error')
      end
    rescue StandardError => e
      Rails.logger.error("Error creating TOC Composition: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:danger] = "Error creating Transition of Care document: #{e.message}"
    end

    redirect_to patient_transition_of_cares_path(patient_id: patient_id)
  end

  # PATCH /patients/:patient_id/transition_of_cares/:id
  def update
    begin
      fhir_composition = Composition.find(params[:id])&.fhir_resource
      fhir_composition ||= find_cached_resource('Composition', params[:id])

      unless fhir_composition
        flash[:danger] = I18n.t('controllers.transition_of_cares.not_found_error')
        redirect_to patient_transition_of_cares_path(patient_id: patient_id)
        return
      end

      updated_composition = TransitionOfCareCompositionService.rebuild(
        composition: fhir_composition,
        patient_id: patient_id,
        toc_params: params[:toc]
      )

      resource = update_resource(updated_composition)

      if resource.present?
        PatientRecordCache.update_patient_record(patient_id, [resource])
        entries = retrieve_current_patient_resources
        Composition.new(resource, entries)
        flash[:success] = I18n.t('controllers.transition_of_cares.update_success')
      else
        flash[:danger] = I18n.t('controllers.transition_of_cares.update_error')
      end
    rescue StandardError => e
      Rails.logger.error("Error updating TOC Composition: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:danger] = "Error updating Transition of Care document: #{e.message}"
    end

    redirect_to patient_transition_of_cares_path(patient_id: patient_id)
  end

  # POST /patients/:patient_id/transition_of_cares/:id/share
  def share
    begin
      toc_id = params[:id]
      destination_organization_ref = params[:destination_organization]
      share_mode = params[:share_mode].presence || 'document'
      target_fhir_server = FhirServer.find(params[:target_fhir_server_id])

      toc = Composition.find(toc_id)
      unless toc
        flash[:danger] = 'Transition of Care document not found'
        redirect_to patient_transition_of_cares_path(patient_id: patient_id)
        return
      end

      case share_mode
      when 'message'
        source_org_id = toc.fhir_resource.custodian&.reference&.split('/')&.last
        destination_org_id = destination_organization_ref.to_s.split('/').last

        raise 'Source organization not found in TOC composition' if source_org_id.blank?
        raise 'Destination organization not specified' if destination_org_id.blank?

        source_organization = PatientRecordCache.lookup('Organization', source_org_id)
        destination_organization = PatientRecordCache.lookup('Organization', destination_org_id)

        raise "Source organization #{source_org_id} not found" unless source_organization
        raise "Destination organization #{destination_org_id} not found" unless destination_organization

        document_url = TransitionOfCareBundleService.perform(
          fhir_server: target_fhir_server,
          composition_id: toc_id
        )

        raise 'Failed to generate TOC bundle document URL' if document_url.blank?

        source_organization = Organization.new(source_organization) unless source_organization.respond_to?(:fhir_resource)
        destination_organization = Organization.new(destination_organization) unless destination_organization.respond_to?(:fhir_resource)

        DischargeNotificationService.perform(
          fhir_server: target_fhir_server,
          patient: @patient,
          source_organization: source_organization,
          destination_organization: destination_organization,
          document_url: document_url,
          document_description: toc.title
        )

        flash[:success] = "Transition of Care message sent successfully to #{target_fhir_server.name}"
      when 'document'
        patient_result = PatientMatchOrCreateService.perform(
          fhir_server: target_fhir_server,
          patient: @patient
        )

        document_url = TransitionOfCareBundleService.perform(
          fhir_server: target_fhir_server,
          composition_id: toc_id
        )

        raise 'Failed to generate TOC bundle document URL' if document_url.blank?

        TransitionOfCareDocumentReferenceService.perform(
          fhir_server: target_fhir_server,
          patient_id: patient_result[:patient_id],
          patient_name: @patient.name,
          document_url: document_url,
          document_description: toc.title
        )

        flash[:success] = "Transition of Care document shared successfully to #{target_fhir_server.name}"
      else
        raise "Unsupported share mode: #{share_mode}"
      end
    rescue ActiveRecord::RecordNotFound
      flash[:danger] = 'Selected FHIR server was not found'
    rescue StandardError => e
      Rails.logger.error("Error sharing transition of care: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:danger] = "Error sharing Transition of Care document: #{e.message}"
    end

    redirect_to patient_transition_of_cares_path(patient_id: patient_id)
  end

  private

  # Sort TOCs from most recent to oldest
  def sort_tocs_by_date(tocs)
    tocs.sort_by do |toc|
      if toc.date == '--'
        Time.zone.at(0)
      else
        begin
          DateTime.strptime(toc.date, '%b %d, %Y')
        rescue ArgumentError
          Time.zone.at(0)
        end
      end
    end.reverse
  end

  def fetch_tocs
    tocs = Composition.tocs_by_patient(patient_id)
    return sort_tocs_by_date(tocs) unless Composition.expired? || tocs.blank?

    entries = retrieve_current_patient_resources
    fhir_compositions = filter_doc_refs_or_compositions_by_category(
      cached_resources_type('Composition'), toc_category_codes
    )

    if fhir_compositions.blank?
      Rails.logger.info('Transition of cares not found in patient record cache, fetching directly')
      entries = fetch_toc_compositions_by_patient(patient_id, Composition.updated_at)
      fhir_compositions = entries.select { |entry| entry.resourceType == 'Composition' }
    end

    entries = (entries + retrieve_other_resources).uniq
    fhir_compositions.each { |entry| Composition.new(entry, entries) }

    # Sort TOCs from most recent to oldest
    sort_tocs_by_date(Composition.tocs_by_patient(patient_id))
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing TOC Composition:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise I18n.t('controllers.transition_of_cares.fetch_error')
  end
end
