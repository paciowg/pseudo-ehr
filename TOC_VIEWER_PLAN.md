Here’s a practical plan for building the TOC Bundle viewer based on the code and sample bundle you shared.


High-level approach

You already have:

 • a bundle controller action that loads a FHIR::Bundle
 • a helper file: app/helpers/document_references_helper.rb
 • a bundle view: app/views/document_references/bundle.html.erb

The cleanest implementation is:

 1 Keep controller logic minimal
    • Continue loading @bundle in the controller.
    • Do not put TOC parsing in the controller.
 2 Put bundle traversal/parsing in DocumentReferencesHelper
    • Find the Composition in the bundle
    • Resolve urn:uuid: and normal references to resources in the bundle
    • Extract:
       • patient/subject
       • author
       • custodian
       • title
       • section metadata
       • section entries
    • Provide helper methods that return display-ready structures
 3 Keep the view mostly declarative
    • Render top context cards
    • Loop over normalized section data
    • Delegate section-specific formatting to helpers

This matches your guideline well: navigation and reference-following in helper, slim view.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggested shape of the helper API

I’d recommend making the helper return a normalized presenter-like hash structure.

Top-level bundle helpers

Add helpers like:

 • toc_composition(bundle)
 • toc_bundle_title(bundle)
 • toc_bundle_subject(bundle)
 • toc_bundle_author(bundle)
 • toc_bundle_custodian(bundle)
 • toc_bundle_sections(bundle)

Reference resolution helpers

These will be the foundation:

 • bundle_entries(bundle)
 • bundle_resource_index(bundle)
 • resolve_bundle_reference(bundle, reference)
 • resolve_section_entry_resources(bundle, section)

Important because your sample bundle uses lots of:

 • urn:uuid:...
 • maybe future relative refs like Patient/123
 • maybe absolute refs

Section formatting helpers

Then a normalized section formatter:

 • toc_sections_for_display(bundle)

That could return something like:


[
  {
    code: '46264-8',
    title: 'Medical Devices',
    empty_reason: nil,
    entries: [
      { type: 'Device', primary: 'Walker, folding, wheeled, adjustable or fixed height', secondary: ['Status: active', 'Code: E0143'] },
      ...
    ]
  },
  ...
]


This gives the view one simple contract.

----------------------------------------------------------------------------------------------------------------------------------------------------


Data extraction plan


1. Identify the Composition

The TOC Bundle profile says the document bundle contains a Composition as the root document entry. Your sample confirms that.

Helper:

 • find first FHIR::Composition in bundle.entry

Use this for:

 • title
 • subject
 • author
 • custodian
 • section list

----------------------------------------------------------------------------------------------------------------------------------------------------


2. Resolve subject / patient context

From Composition.subject.reference, resolve the referenced Patient in the bundle.

Display a compact summary:

 • patient name
 • DOB
 • gender
 • MRN if present
 • maybe address or telecom if easy

That gives useful context without overwhelming the page.

----------------------------------------------------------------------------------------------------------------------------------------------------


3. Resolve author context

Composition.author can point to:

 • Practitioner
 • PractitionerRole
 • Patient

In your sample it points to a PractitionerRole.

So helper should:

 • resolve author resource
 • if PractitionerRole:
    • derive display name from linked practitioner if available
    • derive org from linked organization if available
 • if Practitioner:
    • use practitioner name
 • if Patient:
    • use patient name

Suggested display:

 • Priya Sarkar
 • Emergency Medicine Physician
 • Metro Hospital Emergency Department

----------------------------------------------------------------------------------------------------------------------------------------------------


4. Resolve custodian

Composition.custodian points to an Organization.

Display:

 • organization name
 • maybe telecom or address if present

----------------------------------------------------------------------------------------------------------------------------------------------------


5. Render all sections

The TOC Composition profile defines required named sections, but in the UI I would not hardcode only those names. Instead:

 • iterate the actual composition.section
 • for each section:
    • title
    • code/display
    • emptyReason
    • resolved entry resources

This is more robust and future-friendly.

You can still special-case formatting by section code.

----------------------------------------------------------------------------------------------------------------------------------------------------


6. Section-specific content rendering

I suggest section rendering be driven by section LOINC code, not just title text.

From your FSH and sample, useful section codes include:

 • 42348-3 advance_directives
 • 48765-2 allergies
 • temp behavioral_health_summary
 • 47420-5 functional_status
 • 11369-6 immunizations
 • 69730-0 discharge_instructions
 • 46264-8 medical_devices
 • 10160-0 medications
 • 18776-5 plan_of_care
 • 11450-4 problems
 • 47519-4 procedures
 • 42349-1 reason_for_referral
 • 30954-2 clinical_results
 • 29762-2 social_history
 • 8716-3 vital_signs

Helper should map section code → display formatter.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggested section formatting behavior

Below is a good “basic viewer” scope.

Advance Directives

Likely DocumentReference Show:

 • title
 • type
 • date
 • author

If no entries and emptyReason, show friendly empty text.

Allergies

For each AllergyIntolerance:

 • code / display
 • clinical status
 • verification status
 • criticality
 • category

Behavioral Health

Likely Observation and maybe Condition For each:

 • resource type
 • code / title
 • effective date
 • value if present

Functional Status

Often Observation Show:

 • code
 • effective date
 • value
 • note if present

Immunizations

For each Immunization:

 • vaccine
 • occurrence date
 • status

Discharge Instructions

Could be DiagnosticReport or DocumentReference Show:

 • title/code
 • date
 • status if present

Medical Devices

For each Device:

 • device name
 • type/code
 • status

Your example:

 • “Walker, folding, wheeled...”
 • HCPCS code
 • active

Medications

This section is tricky because TOCBundle allows:

 • List
 • MedicationRequest
 • MedicationStatement
 • Medication

I strongly recommend:

 • show all entries in section order
 • but render each resource appropriately

For example:

List

 • title
 • status
 • date
 • number of entries

MedicationRequest

 • medication name
 • status
 • intent
 • authoredOn

MedicationStatement

 • medication name
 • status
 • dateAsserted

Medication

 • medication code/name

Your sample has a List that points to medication statements, but section entry itself is the List. For a better viewer:

 • show the List
 • and optionally nest the list items by resolving List.entry.item.reference

That would be especially useful here.

Plan of Care

Likely CarePlan Show:

 • title
 • status
 • intent
 • created
 • goals
 • maybe activity descriptions

Problems

Likely Condition Show:

 • code
 • clinical status
 • onset / recorded date
 • body site if present

Procedures

Likely Procedure or ServiceRequest Show:

 • name/code
 • status
 • date

Reason for Transfer

Could contain Condition, Procedure, Observation, Encounter, Composition Show a generic summary:

 • type
 • label/code
 • date/status

Clinical Results

Likely Observation and maybe DiagnosticReport Show:

 • test name
 • effective date
 • value / interpretation
 • reference range if easy

This section benefits from good generic Observation formatting.

Social History

Likely Observation Show:

 • code
 • value
 • effective date

Vital Signs

Mostly Observation Show:

 • code
 • effective date
 • value

If the entry is a panel observation with hasMember, you have two options:

 1 just show the panel and maybe a count
 2 expand member observations

I recommend expanding if hasMember exists, because it’s much more useful.

----------------------------------------------------------------------------------------------------------------------------------------------------


Recommended helper design

I’d structure DocumentReferencesHelper roughly like this:

A. Bundle navigation helpers

 • find composition
 • build fullUrl/resource index
 • resolve references
 • get coding/code display strings
 • get name strings
 • get dates

B. Context helpers

 • subject summary
 • author summary
 • custodian summary

C. Section helpers

 • normalize section metadata
 • resolve section entries
 • section empty state message
 • section-specific formatter

D. Resource display helpers

A generic formatter for each relevant FHIR resource:

 • display_device(resource, bundle)
 • display_medication_request(resource, bundle)
 • display_medication_statement(resource, bundle)
 • display_list(resource, bundle)
 • display_care_plan(resource, bundle)
 • display_condition(resource, bundle)
 • display_observation(resource, bundle)
 • etc.

Then one dispatcher:

 • toc_display_entry(resource, bundle, section_code: nil)

That keeps view logic very small.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggested view structure

For bundle.html.erb, I’d evolve it into:

 1 Back link
 2 Error state
 3 Bundle summary card:
    • title
    • patient
    • author
    • custodian
 4 Sections accordion/cards:
    • section title
    • code
    • empty reason if no entries
    • rendered list/table for entries

A very slim structure would look like:

 • get section array from helper
 • loop through sections
 • for each section:
    • if section has display items, render them
    • else render helper-provided empty message

You can keep it card-based rather than introducing a complex component system.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggestions / implementation choices


Suggestion 1: Normalize to hashes, not raw FHIR objects in the view

Best for keeping the view clean.

Instead of doing this in the view:

 • resource.is_a?(FHIR::Device)
 • resource.deviceName.first.name
 • etc.

Do it in helper and return strings/arrays/hashes.

That will make maintenance much easier.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggestion 2: Use fallback-safe display methods everywhere

FHIR data varies a lot.

For every displayed field, helper should gracefully fallback:

 • title → text → code display → id
 • valueQuantity → valueCodeableConcept → valueString → component summary
 • date → authoredOn → effectiveDateTime → recordedDate → date

This matters a lot for a generic TOC viewer.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggestion 3: Prefer section code matching over title matching

Titles may vary. Codes are much more reliable.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggestion 4: Start with “basic readable summary,” not exhaustive rendering

Your goal says “show basic content for each section,” which is exactly right.

Do not try to build a full clinical document renderer in version 1.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggestion 5: Expand nested structures only when clearly helpful

Examples:

 • List.entry.item in Medications: yes, helpful
 • Observation.hasMember in Vital Signs: yes, helpful
 • every possible chained reference everywhere: probably too much for first pass

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggestion 6: Consider helper memoization

Since the bundle view may repeatedly resolve references, helper methods could memoize indexes for the current bundle object, especially:

 • fullUrl => resource
 • ResourceType/id => resource

This avoids repeated scans of bundle.entry.

----------------------------------------------------------------------------------------------------------------------------------------------------


Suggested phased build


Phase 1

Build basic infrastructure and context:

 • composition finder
 • reference resolver
 • patient summary
 • author summary
 • custodian summary
 • section extraction


Phase 2

Build generic rendering for:

 • Device
 • MedicationRequest
 • MedicationStatement
 • List
 • CarePlan
 • Condition
 • AllergyIntolerance
 • Observation
 • ServiceRequest
 • DocumentReference
 • DiagnosticReport
 • Immunization


Phase 3

Add section-specific polish:

 • medication list nesting
 • vital signs panel expansion
 • plan of care activities/goals
 • emptyReason-friendly labels

----------------------------------------------------------------------------------------------------------------------------------------------------


Questions I’d want answered before building

1. Do you want section entries rendered in simple cards, tables, or mixed?

My recommendation:

 • cards/lists for most sections
 • maybe a simple table only for very tabular data like medications or clinical results

2. Should we show only resources directly referenced in each section, or also expand linked child resources?

Examples:

 • medications: expand List.entry.item? I recommend yes
 • vital signs: expand hasMember? I recommend yes
 • care plans: expand goals and referenced activities? I recommend lightly yes
 • all other chained references: probably no for first pass

3. For author display, do you want the resolved practitioner name when author is a PractitionerRole?

I recommend yes, because it’s much more readable than just “PractitionerRole-...”.

4. Should empty sections display the FHIR emptyReason code in a user-friendly way?

I recommend yes, for example:

 • nilknown → “No known information available”
 • notasked → “Information not asked / not available”

5. Do you want raw JSON available anywhere on the page for debugging?

Optional, but useful during development:

 • collapsible “View raw bundle JSON”
 • or per-section raw data Not necessary for end users.

6. Should this viewer be TOC-specific only, or generic for any Bundle document?

My recommendation:

 • implement it as TOC-focused
 • but keep helpers generic enough that they won’t break on similar document bundles

----------------------------------------------------------------------------------------------------------------------------------------------------


My recommended implementation direction

If I were building this, I would:

 • keep bundle.html.erb as a page with:
    • summary card
    • section cards
 • put all parsing/formatting logic in DocumentReferencesHelper
 • create one main helper:
    • toc_bundle_view_model(@bundle)
 • have that return a full hash for the page:
    • context
    • sections
    • entries already formatted

That gives the slimmest possible view.

Example shape:


{
  title: "...",
  patient: { name: "...", dob: "...", gender: "...", mrn: "..." },
  author: { name: "...", role: "...", organization: "..." },
  custodian: { name: "..." },
  sections: [
    {
      title: "Medical Devices",
      code: "46264-8",
      empty_message: nil,
      items: [
        { heading: "Walker, folding, wheeled, adjustable or fixed height", meta: ["Status: active", "Code: E0143"] }
      ]
    }
  ]
}


That would make the view extremely straightforward.