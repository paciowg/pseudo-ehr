# Device Model
class Device < Resource
  attr_reader :id, :fhir_resource, :identifier, :definition, :udi_carrier, :status, :status_reason,
              :distinct_identifier, :manufacturer, :manufacture_date, :expiration_date, :lot_number,
              :serial_number, :device_name, :model_number, :part_number, :type, :version, :patient,
              :owner, :contact, :location, :url, :note, :safety, :patient_id

  def initialize(fhir_device, bundle_entries = [])
    @id = fhir_device.id
    @fhir_resource = fhir_device
    @identifier = fhir_device.identifier&.map { |id| "#{id.system}: #{id.value}" }&.join(', ')
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @definition = parse_provider_name(fhir_device.definition, bundle_entries)
    @udi_carrier = get_udi_carrier(fhir_device.udiCarrier)
    @status = fhir_device.status
    @status_reason = fhir_device.statusReason&.map { |sr| coding_string(sr.coding) }&.join(', ')
    @distinct_identifier = fhir_device.distinctIdentifier
    @manufacturer = fhir_device.manufacturer
    @manufacture_date = parse_date(fhir_device.manufactureDate)
    @expiration_date = parse_date(fhir_device.expirationDate)
    @lot_number = fhir_device.lotNumber
    @serial_number = fhir_device.serialNumber
    @device_name = get_device_names(fhir_device.deviceName)
    @model_number = fhir_device.modelNumber
    @part_number = fhir_device.partNumber
    @type = coding_string(fhir_device.type&.coding)
    @version = get_versions(fhir_device.version)
    @owner = parse_provider_name(fhir_device.owner, bundle_entries)
    @contact = fhir_device.contact&.map { |c| format_contact(c) }&.join(', ')
    @location = parse_provider_name(fhir_device.location, bundle_entries)
    @url = fhir_device.url
    @note = get_notes(fhir_device.note)
    @safety = fhir_device.safety&.map { |s| coding_string(s.coding) }&.join(', ')

    self.class.update(self)
  end

  private

  def get_udi_carrier(udi_carriers)
    return [] if udi_carriers.blank?

    udi_carriers.map do |udi|
      {
        device_identifier: udi.deviceIdentifier,
        issuer: udi.issuer,
        jurisdiction: udi.jurisdiction,
        carrier_aidc: udi.carrierAIDC,
        carrier_hrf: udi.carrierHRF,
        entry_type: udi.entryType
      }
    end
  end

  def get_device_names(device_names)
    return [] if device_names.blank?

    device_names.map do |name|
      {
        name: name.name,
        type: name.type,
        model: name.modelName
      }
    end
  end

  def get_versions(versions)
    return [] if versions.blank?

    versions.map do |version|
      {
        type: version.type,
        component: version.component&.reference,
        value: version.value
      }
    end
  end

  def format_contact(contact)
    system = contact.system
    value = contact.value
    "#{system}: #{value}"
  end

  def get_notes(notes)
    return [] if notes.blank?

    notes.map do |note|
      {
        author: note.authorString,
        time: parse_date(note.time),
        text: note.text
      }
    end
  end
end
