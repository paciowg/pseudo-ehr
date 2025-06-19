# DiagnosticReport Model
class DiagnosticReport < Resource
  attr_reader :id, :fhir_resource, :status, :effective_datetime, :last_updated, :code, :subject,
              :encounter, :issued, :performer, :results, :media, :contents, :category, :patient_id,
              :patient

  def initialize(fhir_diagnostic_report, bundle_entries = [])
    @id = fhir_diagnostic_report.id
    @fhir_resource = fhir_diagnostic_report
    @status = @fhir_resource.status.presence || '--'
    @category = retrieve_categories
    @effective_datetime = parse_date(@fhir_resource.effectiveDateTime)
    @last_updated = parse_date(@fhir_resource.meta&.lastUpdated).presence || '--'
    @code = coding_string(@fhir_resource.code&.coding).presence || '--'
    @subject = parse_provider_name(@fhir_resource.subject, bundle_entries)
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    # Now retrieving the display, but to be updated to get the encounter instance
    @encounter = @fhir_resource&.encounter&.display&.gsub('_', ' ').presence || '--'
    @issued = parse_date(@fhir_resource.issued)
    @performer = @fhir_resource.performer&.map do |p|
      parse_provider_name(p, bundle_entries)
    end&.join(', ').presence || '--'
    # Results are list of Observation instances (Lab Result Obs)
    @results = get_results(bundle_entries)
    # This will be a list of Content Model instances with the following attribute:
    # title, type, url, and data
    @media = get_media(bundle_entries)
    # These are the contents of presented form. Each content has the following attributes:
    # title, type, url, and data
    @contents = get_presented_forms

    self.class.update(self)
  end

  def raw_date
    fhir_resource.try(:effectiveDateTime).presence || fhir_resource.try(:issued).presence || ''
  end

  def date
    (effective_datetime != '--' && effective_datetime.presence) || issued.presence
  end

  private

  def get_media(bundle_entries)
    media_links = @fhir_resource.media.map { |m| m.link&.reference }.compact
    return [] unless media_links.present?

    media_ids = media_links.map { |link| link.split('/').last }.compact

    medias = bundle_entries.filter { |entry| entry.resourceType == 'Media' && media_ids.include?(entry.id) }
    media_attachments = medias.map(&:content).compact

    media_attachments.map do |ma|
      Content.new(
        title: ma.title, type: ma.contentType, data: ma.data,
        url: ma.url, creation_date: parse_date(ma.creation)
      )
    end
  end

  def get_presented_forms
    forms = @fhir_resource.presentedForm
    return [] unless forms.present?

    forms.map do |form|
      Content.new(
        title: form.title, type: form.contentType, data: form.data,
        url: form.url, creation_date: parse_date(form.creation)
      )
    end
  end

  def get_results(bundle_entries)
    observation_refs = @fhir_resource.result&.map(&:reference)&.compact
    return unless observation_refs.present?

    observation_ids = observation_refs.map { |ref| ref.split('/').last }.compact

    fhir_observations = bundle_entries.filter do |entry|
      entry.resourceType == 'Observation' && observation_ids.include?(entry.id)
    end

    fhir_observations.map { |obs| Observation.new(obs, bundle_entries) }
  end

  def retrieve_categories
    @fhir_resource.category.map do |cat|
      code = cat.coding.first&.code
      display = cat.coding.first&.display

      formatted_cat = "#{display} (#{code})"
      formatted_cat.strip.start_with?('(') ? formatted_cat.strip.delete_prefix('(').delete_suffix(')') : formatted_cat
    end.join(', ')
  end
end
