# CareTeam Model
class CareTeam < Resource
  attr_reader :id, :name, :participants, :patient_id, :patient

  def initialize(fhir_care_team, bundle_entries = [])
    @id = fhir_care_team.id
    @patient_id = fhir_care_team.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @name = fhir_care_team.name
    @participants = get_care_team_participants(fhir_care_team.participant, bundle_entries)

    self.class.update(self)
  end

  private

  def get_care_team_participants(fhir_participants, bundle_entries)
    fhir_participants ||= []
    participants = []
    fhir_participants.each do |participant|
      role = participant.role.first&.text
      name = participant.member.display
      reference_resource_type, reference_id = participant.member.reference&.split('/')

      reference_resource = bundle_entries.find do |resource|
        resource.resourceType == reference_resource_type && resource.id == reference_id
      end
      participants << CareTeamParticipant.new(name, role, reference_resource, bundle_entries)
    end
    participants
  end
end
