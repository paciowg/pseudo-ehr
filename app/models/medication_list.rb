# MedicationList Model
class MedicationList < Resource
  attr_reader :id, :fhir_resource, :status, :title, :code, :date, :medication_statements,
              :patient_id, :patient

  def initialize(fhir_medication_list, bundle_entries = [])
    @id = fhir_medication_list.id
    @fhir_resource = fhir_medication_list
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = @fhir_resource.status
    @title = @fhir_resource.title
    @code = coding_string(@fhir_resource&.code&.coding)
    @date = parse_date(@fhir_resource.date)
    @medication_statements = read_medication_statements(bundle_entries)

    self.class.update(self)
  end

  private

  def read_medication_statements(bundle_entries)
    med_statements = @fhir_resource.entry.filter { |entry| entry.item.reference.include?('MedicationStatement') }
    med_statements.map do |statement|
      resource_type, resource_id = statement.item.reference.split('/')

      medication_statement = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
      next unless medication_statement

      MedicationStatement.new(medication_statement, bundle_entries)
    end.compact
  end
end
