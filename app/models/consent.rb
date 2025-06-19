# Consent Model
class Consent < Resource
  attr_reader :id, :fhir_resource, :status, :scope, :category, :patient, :date_time,
              :performer, :organization, :source_attachment, :policy, :provision,
              :patient_id

  def initialize(fhir_consent, bundle_entries = [])
    @id = fhir_consent.id
    @fhir_resource = fhir_consent
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = fhir_consent.status
    @scope = coding_string(fhir_consent.scope&.coding)
    @category = category_string(fhir_consent.category)
    @date_time = parse_date(fhir_consent.dateTime)
    @performer = parse_provider_name(fhir_consent.performer&.first, bundle_entries) if fhir_consent.performer.present?
    if fhir_consent.organization.present?
      @organization = parse_provider_name(fhir_consent.organization&.first,
                                          bundle_entries)
    end
    @source_attachment = get_source_attachment(fhir_consent.source)
    @policy = get_policy(fhir_consent.policy)
    @provision = get_provision(fhir_consent.provision)

    self.class.update(self)
  end

  def action
    category_string(@provision&.action) if @provision.present?
  end

  private

  def get_source_attachment(source)
    return if source&.attachment.blank?

    attachment = source.attachment
    Content.new(
      title: attachment.title || 'Consent Document',
      type: attachment.contentType,
      data: attachment.data,
      url: attachment.url,
      creation_date: parse_date(attachment.creation)
    )
  end

  def get_policy(policy_array)
    return [] if policy_array.blank?

    policy_array.map do |policy|
      {
        authority: policy.authority,
        uri: policy.uri
      }
    end
  end

  def get_provision(provision)
    return if provision.blank?

    {
      type: provision.type,
      period: format_period(provision.period),
      action: provision.action,
      class: provision.class,
      code: provision.code&.map { |c| coding_string(c.coding) },
      data_period: format_period(provision.dataPeriod),
      data: provision.data&.map { |d| { meaning: d.meaning, reference: d.reference } }
    }
  end

  def format_period(period)
    return if period&.start.blank?

    start_date = parse_date(period.start)
    end_date = period.end.present? ? parse_date(period.end) : 'present'

    "#{start_date} to #{end_date}"
  end
end
