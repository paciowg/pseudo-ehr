require 'rails_helper'

RSpec.describe TransitionOfCaresController, type: :controller do
  let(:patient_id_value) { 'patient-123' }
  let(:toc_id) { 'toc-123' }
  let(:entries) { [] }
  let(:patient) { instance_double(Patient) }

  before do
    allow(controller).to receive(:require_server).and_return(true)
    allow(controller).to receive(:retrieve_patient) do
      controller.instance_variable_set(:@patient, patient)
    end
    allow(controller).to receive(:set_resources_count).and_return(true)
    allow(controller).to receive(:patient_id).and_return(patient_id_value)
    allow(controller).to receive(:current_server).and_return(build_stubbed(:fhir_server))
  end

  describe 'POST #create' do
    let(:created_composition) do
      FHIR::Composition.new(
        id: toc_id,
        title: 'New TOC Title',
        subject: FHIR::Reference.new(reference: "Patient/#{patient_id_value}")
      )
    end

    let(:toc_params) do
      {
        title: 'New TOC Title',
        author: 'Practitioner/prac-1',
        custodian: 'Organization/org-1',
        sections: [
          {
            include: '1',
            title: 'Problems',
            code_system: 'http://loinc.org',
            code: '11450-4',
            display: 'Problem list',
            entries: ['Condition/cond-1', 'Condition/cond-2']
          },
          {
            include: '0',
            title: 'Skipped Section',
            code_system: 'http://loinc.org',
            code: '99999-9',
            display: 'Skipped',
            entries: ['Observation/obs-skip']
          },
          {
            include: '1',
            title: 'Empty Entries Section',
            code_system: 'http://loinc.org',
            code: '10157-6',
            display: 'History of Medication use Narrative',
            entries: []
          }
        ]
      }
    end

    before do
      allow(controller).to receive(:retrieve_current_patient_resources).and_return(entries)
      allow(controller).to receive(:create_resource).and_return(created_composition)
      allow(PatientRecordCache).to receive(:add_resource_to_patient_record)
      allow(Composition).to receive(:new)
    end

    it 'creates a TOC composition, updates cache, and redirects with success' do
      expect(controller).to receive(:create_resource) do |composition|
        expect(composition).to be_a(FHIR::Composition)
        expect(composition.title).to eq('New TOC Title')
        expect(composition.status).to eq('final')
        expect(composition.subject.reference).to eq("Patient/#{patient_id_value}")
        expect(composition.author.first.reference).to eq('Practitioner/prac-1')
        expect(composition.custodian.reference).to eq('Organization/org-1')
        expect(composition.section.length).to eq(1)

        section = composition.section.first
        expect(section.title).to eq('Problems')
        expect(section.code.coding.first.system).to eq('http://loinc.org')
        expect(section.code.coding.first.code).to eq('11450-4')
        expect(section.code.coding.first.display).to eq('Problem list')
        expect(section.entry.map(&:reference)).to eq(['Condition/cond-1', 'Condition/cond-2'])

        created_composition
      end

      expect(PatientRecordCache).to receive(:add_resource_to_patient_record)
        .with(patient_id_value, created_composition)
      expect(Composition).to receive(:new).with(created_composition, entries)

      post :create, params: { patient_id: patient_id_value, toc: toc_params }

      expect(response).to redirect_to(patient_transition_of_cares_path(patient_id: patient_id_value))
      expect(flash[:success]).to eq(I18n.t('controllers.transition_of_cares.create_success'))
    end
  end

  describe 'PATCH #update' do
    let(:existing_composition) do
      FHIR::Composition.new(
        id: toc_id,
        title: 'Original Title',
        date: '2024-01-01T00:00:00Z',
        subject: FHIR::Reference.new(reference: "Patient/#{patient_id_value}"),
        section: [
          FHIR::Composition::Section.new(
            title: 'Old Section',
            entry: [FHIR::Reference.new(reference: 'Condition/old')]
          )
        ]
      )
    end

    let(:composition_record) do
      instance_double(Composition, fhir_resource: existing_composition)
    end

    let(:updated_resource) do
      existing_composition
    end

    let(:toc_params) do
      {
        title: 'Updated TOC Title',
        sections: [
          {
            include: '1',
            title: 'Updated Problems',
            code_system: 'http://loinc.org',
            code: '11450-4',
            display: 'Problem list',
            entries: ['Condition/cond-9']
          },
          {
            include: '0',
            title: 'Not Included',
            code_system: 'http://loinc.org',
            code: '88888-8',
            display: 'Ignore Me',
            entries: ['Observation/obs-1']
          },
          {
            include: '1',
            title: 'Section Without Entries',
            code_system: 'http://loinc.org',
            code: '77777-7',
            display: 'No Entries',
            entries: []
          }
        ]
      }
    end

    before do
      allow(Composition).to receive(:find).with(toc_id).and_return(composition_record)
      allow(controller).to receive(:retrieve_current_patient_resources).and_return(entries)
      allow(controller).to receive(:update_resource).and_return(updated_resource)
      allow(PatientRecordCache).to receive(:update_patient_record)
      allow(Composition).to receive(:new)
    end

    it 'updates a TOC composition, refreshes cache, and redirects with success' do
      expect(controller).to receive(:update_resource) do |composition|
        expect(composition).to be_a(FHIR::Composition)
        expect(composition.id).to eq(toc_id)
        expect(composition.title).to eq('Updated TOC Title')
        expect(composition.section.length).to eq(2)

        first_section = composition.section.first
        expect(first_section.title).to eq('Updated Problems')
        expect(first_section.code.coding.first.system).to eq('http://loinc.org')
        expect(first_section.code.coding.first.code).to eq('11450-4')
        expect(first_section.code.coding.first.display).to eq('Problem list')
        expect(first_section.entry.map(&:reference)).to eq(['Condition/cond-9'])

        second_section = composition.section.second
        expect(second_section.title).to eq('Section Without Entries')
        expect(second_section.entry).to be_nil.or eq([])

        updated_resource
      end

      expect(PatientRecordCache).to receive(:update_patient_record)
        .with(patient_id_value, [updated_resource])
      expect(Composition).to receive(:new).with(updated_resource, entries)

      patch :update, params: { patient_id: patient_id_value, id: toc_id, toc: toc_params }

      expect(response).to redirect_to(patient_transition_of_cares_path(patient_id: patient_id_value))
      expect(flash[:success]).to eq(I18n.t('controllers.transition_of_cares.update_success'))
    end
  end

  describe 'DELETE #destroy' do
    before do
      allow(controller).to receive(:delete_resource)
      allow(Composition).to receive(:remove)
      allow(PatientRecordCache).to receive(:remove_resource_from_patient_record)
    end

    it 'deletes a TOC composition, removes it from cache, and redirects with success' do
      expect(controller).to receive(:delete_resource).with(FHIR::Composition, toc_id)
      expect(Composition).to receive(:remove).with(toc_id)
      expect(PatientRecordCache).to receive(:remove_resource_from_patient_record)
        .with(patient_id_value, 'Composition', toc_id)

      delete :destroy, params: { patient_id: patient_id_value, id: toc_id }

      expect(response).to redirect_to(patient_transition_of_cares_path(patient_id: patient_id_value))
      expect(flash[:success]).to eq('Transition of Care document deleted successfully.')
    end
  end
end
