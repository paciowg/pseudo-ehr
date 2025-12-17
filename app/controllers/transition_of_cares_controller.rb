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
      # Create a new TOC Composition
      composition_data = build_toc_composition(params[:toc])

      # Send the composition to the FHIR server
      fhir_composition = create_resource(composition_data)

      if fhir_composition.present?
        # Update the cache with the new composition
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

      fhir_composition.title = params[:toc][:title]
      fhir_composition.date = Time.now.iso8601

      # Clear existing sections and add updated ones
      fhir_composition.section = []

      # Add the selected sections
      params[:toc][:sections].each do |section_params|
        next unless section_params[:include] == '1'

        section = FHIR::Composition::Section.new(
          title: section_params[:title],
          code: {
            coding: [
              {
                system: section_params[:code_system],
                code: section_params[:code],
                display: section_params[:display]
              }
            ]
          }
        )

        # Add entries to the section if provided
        if section_params[:entries].present?
          section.entry = section_params[:entries].map do |entry|
            FHIR::Reference.new(reference: entry)
          end
        end

        fhir_composition.section << section
      end

      resource = update_resource(fhir_composition)

      if resource.present?
        # Update the cache with the updated composition
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

  # POST /patients/:patient_id/transition_of_cares/:id/notify
  def notify
    begin
      toc_id = params[:id]
      destination_organization_ref = params[:destination_organization]

      # Find the TOC Composition
      toc = Composition.find(toc_id)
      unless toc
        flash[:danger] = "Transition of Care document not found"
        redirect_to patient_transition_of_cares_path(patient_id: patient_id)
        return
      end

      # Step 1: Generate the TOC Bundle and get the document URL
      document_url = TransitionOfCareBundleService.perform(
        fhir_server: current_server,
        composition_id: toc_id
      )

      raise "Failed to generate TOC bundle document URL" unless document_url.present?

      # Step 2: Extract organization IDs from references
      # Source organization is the custodian from the composition
      source_org_id = toc.fhir_resource.custodian&.reference&.split('/')&.last
      destination_org_id = destination_organization_ref.split('/').last

      raise "Source organization not found in TOC composition" unless source_org_id.present?
      raise "Destination organization not specified" unless destination_org_id.present?

      # Get Organization objects
      source_organization = Organization.find(source_org_id)
      destination_organization = Organization.find(destination_org_id)

      raise "Source organization #{source_org_id} not found" unless source_organization
      raise "Destination organization #{destination_org_id} not found" unless destination_organization

      # Step 3: Send the discharge notification
      DischargeNotificationService.perform(
        fhir_server: current_server,
        patient: @patient,
        source_organization: source_organization,
        destination_organization: destination_organization,
        document_url: document_url,
        document_description: toc.title
      )

      flash[:success] = "Discharge notification sent successfully to #{destination_organization.name}"
    rescue StandardError => e
      Rails.logger.error("Error sending discharge notification: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:danger] = "Error sending discharge notification: #{e.message}"
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

  def build_toc_composition(toc_params)
    # Create a new FHIR Composition resource
    composition = FHIR::Composition.new(
      status: 'final',
      type: {
        coding: [
          {
            system: 'http://loinc.org',
            code: '18842-5',
            display: 'Discharge summary'
          }
        ]
      },
      category: [
        {
          coding: [
            {
              system: 'http://loinc.org',
              code: '18761-7',
              display: 'Transfer Summary Note'
            }
          ]
        }
      ],
      subject: {
        reference: "Patient/#{patient_id}"
      },
      date: Time.now.iso8601,
      title: toc_params[:title],
      author: [
        {
          reference: toc_params[:author]
        }
      ],
      custodian: {
        reference: toc_params[:custodian]
      }
    )

    # Add sections to the composition
    composition.section = []

    # Add the selected sections
    toc_params[:sections].each do |section_params|
      next unless section_params[:include] == '1' && section_params[:entries].present?

      section = FHIR::Composition::Section.new(
        title: section_params[:title],
        code: {
          coding: [
            {
              system: section_params[:code_system],
              code: section_params[:code],
              display: section_params[:display]
            }
          ]
        }
      )

      # Add entries to the section if provided
      section.entry = section_params[:entries].map do |entry|
        FHIR::Reference.new(reference: entry)
      end

      composition.section << section
    end

    composition
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

    entries = (entries + retrieve_practitioner_roles).uniq
    fhir_compositions.each { |entry| Composition.new(entry, entries) }

    # Sort TOCs from most recent to oldest
    sort_tocs_by_date(Composition.tocs_by_patient(patient_id))
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing TOC Composition:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise I18n.t('controllers.transition_of_cares.fetch_error')
  end
end
