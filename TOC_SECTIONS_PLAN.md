# Plan: Add Medical Devices and Functional Status Sections to TOC Composition

1) Context

- Reference implementation guide:
  - Transition of Care Composition (TOC-Composition): https://build.fhir.org/ig/HL7/fhir-transitions-of-care-ig/StructureDefinition-TOC-Composition.html
  - Relevant section slices to support in this phase:
    - Medical Devices (section:medical_devices)
      - Code system: http://loinc.org
      - Code: 46264-8
      - Display (human label in UI): “Medical Devices” (often referred to as “Medical equipment”)
      - Entries: Device resources
    - Functional Status (section:functional_status)
      - Code system: http://loinc.org
      - Code: 47420-5
      - Display: “Functional Status”
      - Entries: Observations and/or PACIO PFE artifacts (the IG allows Observation and PFE-specific profiles)
- Current app behavior:
  - The TOC create/update flow is driven by:
    - app/views/transition_of_cares/_create_toc_modal.html.erb: renders a modal with a checklist of sections and entry lists per section.
    - app/javascript/controllers/toc_form_controller.js: Stimulus controller powering auto-fill and “select all entries” behavior using section IDs and entry CSS class selectors.
    - app/controllers/transition_of_cares_controller.rb: build_toc_composition constructs a FHIR::Composition based on submitted params; update updates an existing Composition. Both already support arbitrary sections and entries when the form provides the correct code system/code/display and entry references.
  - Resource fetching/caching:
    - app/helpers/resource_fetch_helper.rb defines which resource types are fetched and cached for a patient. Device is currently NOT in PATIENT_RELATED_RESOURCES, so Devices may not be loaded unless returned by $everything or fetched directly.
    - The app primarily uses Patient/$everything via fetch_single_patient_record to populate PatientRecordCache; if the connected server’s $everything includes Device, we’ll see Device entries without further changes. If not, we may supplement the patient record retrieval with a Device search.
    - ApplicationController#get/grouped patient record and helpers expose cached resources to views/partials via cached_resources_for_select.
  - Backend parsing and bundling:
    - app/models/composition.rb understands Device and Observation entries and maps them to model objects for rendering.
    - app/services/transition_of_care_bundle_service.rb crawls Composition references and includes them in the submitted Bundle (no special case needed for Device/Functional Status beyond what already exists).
  - UI sections currently implemented in _create_toc_modal.html.erb: Allergies, Medications (including Lists and MedicationRequests), Problems, Procedures, Results, Vital Signs, Immunizations, Advance Directives. Missing: Medical Devices, Functional Status.

2) High-level approach

- Data layer:
  - Ensure Device resources are fetched and cached by patient by adding :Device to PATIENT_RELATED_RESOURCES in ResourceFetchHelper so fetch_devices_by_patient is auto-generated and available for on-demand loads.
  - Rely on Patient/$everything for baseline loading. If $everything does not return Device from the target server, optionally supplement retrieve_current_patient_resources to merge in fetch_devices_by_patient results for the active patient.
  - Functional Status entries will be built from Observations; filter Observations that carry a us-core-category coding with code “functional-status” (system: http://hl7.org/fhir/us/core/CodeSystem/us-core-category). Do not add model methods; perform this filtering inline in the views using the raw FHIR category codings.
- Controller/composition:
  - No structural changes are required; the controller already assembles sections generically from form input (code system/code/display/title and entry references).
  - Conformance note: The TOC IG marks Composition.section.text as required (1..1). We will keep current behavior (no section.text) in this phase and add a TODO comment in code as a placeholder for later implementation.
- UI/form:
  - Extend app/views/transition_of_cares/_create_toc_modal.html.erb with two new sections:
    - “Medical Devices” with LOINC 46264-8 and entries sourced from cached Device resources.
    - “Functional Status” with LOINC 47420-5 and entries sourced from filtered Observations using an inline raw FHIR category coding check.
  - Update app/javascript/controllers/toc_form_controller.js:
    - Add these new sections to sectionEntryMap so Auto-Fill and “All” buttons work.
    - Ensure the per-entry checkboxes use class names that match the map (e.g., `.device-entry`, `.observation-functional-entry`).

3) Specific instructions and files to edit

A. Fetch/Cache Devices by Patient
- File: app/helpers/resource_fetch_helper.rb
  - Change: Add :Device to PATIENT_RELATED_RESOURCES so fetch_devices_by_patient is auto-generated and devices can be loaded like other patient-related resources.
  - No additional parameters are required beyond what helpers already support (_count, _since, etc.).
  - If the $everything response from the server does not include Device, consider supplementing ApplicationController#retrieve_current_patient_resources to merge in fetch_devices_by_patient(patient_id) results.

B. Add Medical Devices section to TOC form
- File: app/views/transition_of_cares/_create_toc_modal.html.erb
  - Add a section block similar to the existing sections with:
    - Checkbox id: section_medical_devices
    - Hidden fields:
      - toc[sections][][title] = "Medical Devices"
      - toc[sections][][code] = "46264-8"
      - toc[sections][][code_system] = "http://loinc.org"
      - toc[sections][][display] = "Medical Devices"
    - Entries list:
      - Iterate cached_resources_for_select('Device')
      - Each entry checkbox value: "Device/<id>"
      - Checkbox class: "entry-checkbox device-entry"
      - Label text: use Device.type display/code (per decision); fallback "Device/<id>"
    - “All” button: data-section-id="section_medical_devices" to work with selectAllEntries.

C. Add Functional Status section to TOC form
- File: app/views/transition_of_cares/_create_toc_modal.html.erb
  - Add a section block with:
    - Checkbox id: section_functional_status
    - Hidden fields:
      - toc[sections][][title] = "Functional Status"
      - toc[sections][][code] = "47420-5"
      - toc[sections][][code_system] = "http://loinc.org"
      - toc[sections][][display] = "Functional Status"
    - Entries list:
      - Source: cached_resources_for_select('Observation').
      - Filter inline on raw FHIR objects’ category codings: include only Observations where any category.coding has system 'http://hl7.org/fhir/us/core/CodeSystem/us-core-category' and code 'functional-status'.
      - Checkbox value: "Observation/<id>"
      - Checkbox class: "entry-checkbox observation-functional-entry"
      - Label text: observation.code.text or fallback "Observation/<id>"
    - “All” button: data-section-id="section_functional_status".

D. Update Stimulus auto-fill mappings
- File: app/javascript/controllers/toc_form_controller.js
  - Update sectionEntryMap to include:
    - 'section_medical_devices': '.device-entry'
    - 'section_functional_status': '.observation-functional-entry'

E. Update Edit TOC form
- File: app/views/transition_of_cares/_edit_toc_modal.html.erb
  - Add parallel sections for “Medical Devices” (LOINC 46264-8) and “Functional Status” (LOINC 47420-5) to the edit modal, following the patterns used for existing sections:
    - Device entries: iterate cached Device resources; checkbox class should be entry-checkbox-#{identifier} device-entry-#{identifier}; label uses type display/code.
    - Functional Status entries: iterate cached Observations and filter inline on the raw FHIR category codings for us-core-category code 'functional-status'; checkbox class should be entry-checkbox-#{identifier} observation-functional-entry-#{identifier}.
  - For Vital Signs in the edit modal, also prefer the raw category coding check (code 'vital-signs' in system http://hl7.org/fhir/us/core/CodeSystem/us-core-category) for consistency.

F. Optional/ancillary improvements
- File: app/controllers/application_controller.rb
  - Cache clearing: Add Device to PATIENT_MODELS so clear_models_data_for_patient resets Device data per patient (we will not add @device_count or UI elements at this time).
- Files that require no changes for this phase (verify behavior only):
  - app/controllers/transition_of_cares_controller.rb
    - Already builds/updates sections from form params; we’ll add a TODO comment in relevant code paths noting section.text should be set in a future phase to meet the IG requirement.
  - app/models/composition.rb
    - Already recognizes Device and Observation.
  - app/services/transition_of_care_bundle_service.rb
    - Will include Devices and Observations referenced by the Composition.
  - app/models/device.rb, app/models/observation.rb
    - Parsing/rendering remains the same; ensure labels in the form are meaningful.
    - Minor cleanup to schedule: Fix a typo in Observation (attr_reader lists :local_mentod but code uses @local_method).

Summary list of files to edit (with repository paths):
- app/helpers/resource_fetch_helper.rb
- app/views/transition_of_cares/_create_toc_modal.html.erb
- app/views/transition_of_cares/_edit_toc_modal.html.erb
- app/javascript/controllers/toc_form_controller.js
- app/controllers/application_controller.rb (add Device to PATIENT_MODELS; add TODO comment for section.text in controller if desired)

Conformance note (deferred this phase)
- We will not set Composition.section.text in this phase even though the IG requires it (1..1). Add a TODO comment in TransitionOfCaresController#create and #update near where sections are created to indicate this must be added in a subsequent phase.

4) QA/Validation steps (post-implementation)
- Open a patient, open “Create New TOC”, confirm two new sections (Medical Devices, Functional Status) appear.
- Auto-Fill selects both sections and populates entries if available; the “All” buttons select all entries in their sections.
- Create a TOC; verify:
  - FHIR Composition contains new sections with correct code system/code.
  - Each section has entry references to Device or Observation resources as selected.
  - Bundle submission via TransitionOfCareBundleService includes referenced Devices/Observations.
- If the environment’s $everything does not include Device, verify supplemental Device search is either added or not required for your target server.

5) Open questions resolved in this phase

- Functional Status filtering:
  - Decision: Start by filtering to Observations that have a us-core-category of "functional-status" (system http://hl7.org/fhir/us/core/CodeSystem/us-core-category). Perform this filtering inline in the views (create and edit modals) using the raw FHIR category codings; do not add a model method at this time.
- Section narrative (Composition.section.text):
  - Decision: Defer implementation in this phase. Add a TODO comment in controller code noting that section.text (FHIR::Narrative) should be generated in a future phase.
- Device display in the form:
  - Decision: Show Device.type (display and code) in labels.
- Counts/UI:
  - Decision: Do not add @device_count to set_resources_count, as we do not plan a dedicated Device page/menu at this time.
- Data availability:
  - Decision: Assume Device?patient= is supported. Continue relying on $everything; if Device is not included by $everything, consider supplementing with fetch_devices_by_patient.
- Internationalization:
  - Decision: Hard-coded text for labels/tooltips is acceptable in this phase.

6) Minor cleanups scheduled with implementation
- Fix the Observation typo (attr_reader :local_mentod → :local_method and related variable name) when making code changes.
- Add TODO comments around Composition section construction noting section.text generation is pending.

— End of plan —
