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

1. Connect to a FHIR server
2. List Patient records on that server
3. Allow the user to filter or search patients
4. Select a patient
5. Load that patient's data primarily through `Patient/{id}/$everything`
6. Display a patient summary page

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

### Primary patient detail loading strategy

The primary mechanism for loading patient detail is:

- `Patient/{id}/$everything`

The patient summary page should derive both summary information and clinical summary sections from the patient resource and returned bundle data.

### Failure and fallback rule

If `$everything` fails, is unsupported, or returns incomplete related-resource data:

- the app should still display whatever can be derived from the `Patient` resource itself
- related clinical sections that depend on bundle data should be shown as unavailable or empty as appropriate
- the implementation should not introduce a large first-pass fallback system that issues many separate resource-type queries

This keeps Phase 1 simpler while still allowing graceful degradation.

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
  - if missing, display a standard missing-value placeholder

- gender
  - use `gender`
  - if missing, display a standard missing-value placeholder

- medical record number
  - use the first identifier whose `type.coding.code` is `MR`

- marital status
  - derive from `maritalStatus.coding.first.code`
  - apply a code-to-display mapping

- language
  - derive from `communication.first.language.coding.first.code`
  - display uppercase code where appropriate
  - if missing, display a standard missing-value placeholder

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
- missing relationship may fall back to an `"Unknown"`-style display label

### Clinical section sources

For the first implementation pass, the clinical summary sections should use these source assumptions:

- Active Problems
  - `Condition`
- Current Medications
  - `MedicationRequest`
- Known Allergies
  - `AllergyIntolerance`
- Most Recent Vitals
  - `Observation`

These source assumptions are sufficient for the sample data and the initial POC, even if they are not a perfect clinical abstraction for every production use case.

## Display conventions

The exact wording can be refined during implementation, but the app should use consistent conventions for:

- missing patient field values
- empty emergency contact lists
- empty clinical summary sections
- unavailable bundle-derived data

A likely initial convention is:

- use a placeholder such as `--` or `—` for missing simple field values
- use `None recorded` for empty clinical lists
- use `Unavailable` when a section cannot be computed due to missing or failed bundle data

## Initial route assumptions

The current route direction is:

- `/` for server selection / connection
- `/patients` for patient list
- `/patients/:id` for patient summary

These routes are considered a good starting point for the initial implementation sketch.

## Architectural direction

The browser client should favor a clear separation between:

- FHIR fetch logic
- data transformation / semantic helpers
- React page and component rendering
- local browser persistence for saved servers and related client state

The implementation should remain simple and understandable rather than mirroring the Rails app's backend-oriented layers.

## Non-blocking open questions

The following questions remain open, but they do not block implementation sketching:

- whether the clinical summary cards will later become navigable
- whether a query/debug panel should be included in Phase 1
- whether fixture-based mock data should be included immediately for local development
- the exact final placeholder text for missing and unavailable values
- the exact component and folder structure inside the React application

## Immediate next step

The next step after this document is to sketch the initial implementation for Phase 1, including:

- page structure
- route structure
- component hierarchy
- data-fetch flow
- patient-summary view model / helper responsibilities
- derivation approach for:
  - active problems
  - current medications
  - known allergies
  - most recent vitals

This document should be updated as implementation decisions become more concrete.
