# Browser Client POC Implementation Plan

## Purpose

This document captures the current implementation plan and the decisions made to date for the standalone browser-based PACIO POC in `browser_client_poc/`.

This POC is intended to:

- have no code or dependency relationship to the existing Rails application
- serve as a clearer and more accessible reference implementation
- run as a browser-based client without requiring a backend application server
- support hosting scenarios such as GitHub Pages
- begin with a focused, read-only Phase 1 that establishes the core application structure for future PACIO capabilities

## Relationship to the existing Rails app

This POC will not share code with the Rails application, but it may take inspiration from the Rails app in areas such as:

- the user workflow
- the kinds of patient data shown on the patient page
- the semantic interpretation of FHIR data

The browser POC should use a new visual design and should aim to present a simpler, more declarative implementation.

## Phase 1 goals

Phase 1 will support the following core flow:

1. Connect to a FHIR R4 server
2. List Patient records on that server
3. Allow client-side patient filtering after loading up to 100 patients
4. Select a patient
5. Load that patient's data primarily through `Patient/{id}/$everything`
6. If needed, fall back to `Patient/{id}`
7. Display a patient summary page

Phase 1 should be implemented in a way that supports future PACIO-oriented enhancements without requiring major restructuring.

## Phase 1 scope decisions

The following decisions have been made.

### Read-only scope

Phase 1 is read-only.

This means the POC will not include:

- updating patient information
- deleting patient records
- sync or mutation actions
- other write operations against the FHIR server

The Rails patient page may be used as inspiration for displayed information, but not for mutation features in Phase 1.

### Routing

Phase 1 uses a tiny hand-rolled hash-based route switch rather than React Router.

Current route targets:

- `#/` for server selection / connection
- `#/patients` for patient list
- `#/patients/:id` for patient summary

This choice keeps the app lightweight and compatible with static hosting environments such as GitHub Pages.

### Browser persistence

Saved servers are stored in browser local storage.

Rules:

- localStorage key for saved servers: `pacio.browserClient.savedServers`
- localStorage key for active server: `pacio.browserClient.activeServer`
- uniqueness is based on normalized base URL
- normalized base URL removes leading/trailing whitespace and trailing slashes
- latest used server moves to the top of the saved list
- label is editable metadata associated with the server

### FHIR version target

Phase 1 targets FHIR R4.

The implementation assumes open browser-accessible FHIR R4 demo servers.

### Patient summary content

The Phase 1 patient summary page should display Rails-inspired content including:

- personal information
- contact information
- demographics
- emergency contacts
- clinically oriented summary sections for:
  - active problems
  - current medications
  - known allergies
  - most recent vitals

### Clinical summary sections

The patient page should include the following non-interactive clinical summary sections:

- Active Problems
- Current Medications
- Known Allergies
- Most Recent Vitals

For the first pass:

- these sections are display-only
- each section should show up to 10 items
- each section should show dates when available
- each section should show a clear empty state such as `None recorded`

### Patient page layout

The initial patient page should follow this general layout:

- top summary header / quick stats
- main content area containing:
  - personal information card
  - demographics card
  - contact information card
  - emergency contacts card
  - clinical summary cards for:
    - active problems
    - current medications
    - known allergies
    - most recent vitals

This layout is intentionally inspired by the Rails patient summary while allowing a fresh visual design for the browser POC.

## Data-loading approach

### Server validation strategy

The connect flow validates the target server using `GET /metadata`.

The server is considered connectable when the response is a `CapabilityStatement` and reports a FHIR version beginning with `4.`.

### Primary patient detail loading strategy

The primary mechanism for loading patient detail is:

- `Patient/{id}/$everything`

The patient summary page derives both summary information and clinical summary sections from the patient resource and returned bundle data.

### Failure and fallback rule

If `$everything` fails, is unsupported, or returns incomplete related-resource data:

- the app should still display whatever can be derived from the `Patient` resource itself
- related clinical sections that depend on bundle data should be shown as unavailable
- the implementation should not introduce a large first-pass fallback system that issues many separate resource-type queries

If `Patient/{id}` also fails:

- the page should show an error state

## FHIR data extraction rules

Where possible, the browser POC should base field extraction behavior on the Rails `Patient` model currently used as a reference:

- `app/models/patient.rb`

The goal is not to reproduce Rails implementation details exactly, but to preserve the same semantic interpretation where it makes sense.

### Patient identity and basic fields

Use the following extraction rules where possible:

- `id` and `patient_id`
  - use `Patient.id`

- name
  - derive first name and last name from the patient's name data
  - provide a combined display name

- date of birth
  - use `birthDate`
  - if missing, display `--`

- gender
  - use `gender`
  - if missing, display `--`

- medical record number
  - use the first identifier whose `type.coding.code` is `MR`

- marital status
  - derive from `maritalStatus.coding.first.code`
  - apply a code-to-display mapping

- language
  - derive from `communication.first.language.coding.first.code`
  - display uppercase code where appropriate
  - if missing, display `--`

### Contact information

Use the patient resource to derive:

- address
- phone
- email

These should follow logic equivalent to the Rails formatting helpers where possible, while remaining appropriate for a browser TypeScript implementation.

### Demographic characteristics

Use US Core extensions where present to derive:

- race
- ethnicity
- birth sex

Specifically:

- `http://hl7.org/fhir/us/core/StructureDefinition/us-core-race`
- `http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity`
- `http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex`

For race and ethnicity, use `ombCategory` display values when present.

### Emergency contacts

Emergency contacts should be derived from `Patient.contact`.

For each contact, where possible extract:

- relationship
- name
- phone
- email
- address

Follow Rails-inspired behavior where possible:

- relationship comes from the first relationship coding and may be mapped to a friendlier label
- name may come from `contact.name.text`, or from formatted structured name data
- address may come from `contact.address.text`, or from formatted structured address data
- missing relationship may fall back to an `Unknown` display label

### Clinical section sources

For the first implementation pass, the clinical summary sections should use these source assumptions:

- Active Problems
  - `Condition`
- Current Medications
  - `MedicationStatement`
- Known Allergies
  - `AllergyIntolerance`
- Most Recent Vitals
  - `Observation`

### Clinical inclusion rules

Current inclusion rules for the first pass:

- Active Problems
  - include `Condition`
  - prefer active / recurrence / relapse clinical status values when present

- Current Medications
  - include `MedicationStatement`
  - prefer statuses such as `active`, `completed`, `intended`, and `on-hold` when present

- Known Allergies
  - include `AllergyIntolerance`
  - exclude entries explicitly marked `entered-in-error`

- Most Recent Vitals
  - include `Observation`
  - use final or amended observations where practical
  - derive one latest entry for:
    - blood pressure
    - heart rate
    - respiratory rate
    - body temperature
    - oxygen saturation
  - blood pressure should support panel/component extraction

## Display conventions

Use consistent conventions for:

- missing patient field values
- empty emergency contact lists
- empty clinical summary sections
- unavailable bundle-derived data

Current conventions:

- missing scalar field values: `--`
- empty loaded clinical lists: `None recorded`
- bundle-derived sections unavailable due to fallback: `Unavailable`

## Architectural direction

The browser client should favor a clear separation between:

- FHIR fetch logic
- data transformation / semantic helpers
- React page and component rendering
- local browser persistence for saved servers and related client state

Current lightweight structure:

- `src/lib/fhir/`
- `src/lib/routing/`
- `src/features/servers/`
- `src/features/patients/`
- `src/features/patientSummary/`
- `src/components/`

## Immediate next step

The current next step is Phase 1 implementation and refinement against selected demo servers.

This document should be updated as implementation decisions become more concrete.
