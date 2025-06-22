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
      response = client.create(composition_data)

      fhir_composition = response.resource

      if fhir_composition.present?
        # Update the cache with the new composition
        PatientRecordCache.add_resource_to_patient_record(patient_id, fhir_composition)
        entries = retrieve_current_patient_resources
        Composition.new(fhir_composition, entries)
        flash[:success] = 'Transition of Care document created successfully.'
      else
        flash[:danger] = 'Failed to create Transition of Care document.'
      end
    rescue StandardError => e
      Rails.logger.error("Error creating TOC Composition: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:danger] = "Error creating Transition of Care document: #{e.message}"
    end

    redirect_to patient_transition_of_cares_path(patient_id: patient_id)
  end

  private

  # Sort TOCs from most recent to oldest
  def sort_tocs_by_date(tocs)
    tocs.sort_by do |toc|
      if toc.date == '--'
        Time.at(0)
      else
        begin
          DateTime.strptime(toc.date, '%b %d, %Y')
        rescue ArgumentError
          Time.at(0)
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
            code: '81218-0',
            display: 'Discharge summary - recommended C-CDA R2.1 sections'
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
