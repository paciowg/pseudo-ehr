import type {
  Binary,
  Bundle,
  BundleEntry,
  CodeableConcept,
  Composition,
  Patient,
  Practitioner,
  PractitionerRole,
  Reference,
  Resource,
} from 'fhir/r4'
import { createBundle } from '../lib/fhir/client'
import { withUrnUuidBundleReferences } from '../lib/fhir/bundleReferences'
import { closeBundleReferences } from '../lib/fhir/closedBundle'
import {
  formatAdiVersionNumber,
  getDisplayNameFromHumanName,
  getPractitionerRoleDisplayName,
} from '../lib/fhir/formatters'

export type PmoStatus = 'preliminary' | 'final' | 'amended'

export type PmoAttesterOption = {
  reference: string
  display: string
}

export type PmoDataEntererOption = {
  reference: string
  display: string
}

export type CreateAdiPmoBundleInput = {
  patient: Patient
  practitionerRole: PractitionerRole
  practitionerByReference: Map<string, Practitioner>
  attester: PmoAttesterOption
  facilitator?: Reference
  dataEnterer?: PmoDataEntererOption
  custodian?: Reference
  status: PmoStatus
  signedDate: string
  createdAt: string
  pdfBase64: string
}

const ADI_SOURCE_FORM_BINARY_PROFILE =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/ADI-ADISourceFormInformation'
const ADI_PMO_COMPOSITION_PROFILE =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/ADI-PMOComposition'
const ADI_DOC_VERSION_EXTENSION_URL =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-docVersionNumber-extension'
const ADI_DATA_ENTERER_EXTENSION_URL =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-dataEnterer-extension'
const ADI_TEMP_CODE_SYSTEM = 'http://hl7.org/fhir/us/pacio-adi/CodeSystem/ADITempCS'
const ADI_DOCUMENT_IDENTIFIER_SYSTEM =
  'https://pacioproject.org/adi-document-identifier'
const ACP_SERVICES_CODE = {
  system: ADI_TEMP_CODE_SYSTEM,
  code: 'acp-services',
  display: 'Advance care planning services',
} as const

function createPmoType(): CodeableConcept {
  return {
    coding: [
      {
        system: 'http://loinc.org',
        code: '93037-0',
        display: 'Portable medical order form',
      },
    ],
    text: 'Portable medical order form',
  }
}

function createClinicalNoteCategory(): CodeableConcept {
  return {
    coding: [
      {
        system: 'http://loinc.org',
        code: '107903-7',
        display: 'Clinical note',
      },
    ],
    text: 'Clinical note',
  }
}

function createAhdCategory(): CodeableConcept {
  return {
    coding: [
      {
        system: 'http://loinc.org',
        code: '42348-3',
        display: 'Advance healthcare directives',
      },
    ],
    text: 'Advance healthcare directives',
  }
}

function getPatientDisplayName(patient: Patient) {
  return getDisplayNameFromHumanName(patient.name?.[0]) || patient.id || 'Unknown patient'
}

function buildSourceFormBinary(input: CreateAdiPmoBundleInput): Binary {
  return {
    resourceType: 'Binary',
    id: SOURCE_FORM_BINARY_ID,
    meta: {
      profile: [ADI_SOURCE_FORM_BINARY_PROFILE],
    },
    contentType: 'application/pdf',
    data: input.pdfBase64,
  }
}

const SOURCE_FORM_BINARY_ID = 'source-form-binary'

function getStatusLabel(status: PmoStatus) {
  return status.charAt(0).toUpperCase() + status.slice(1)
}

function buildCompositionNarrative(input: {
  patientDisplayName: string
  authorDisplayName: string
  attesterDisplay: string
  signedDate: string
  status: PmoStatus
  facilitatorDisplay?: string
  dataEntererDisplay?: string
}) {
  const detailParts = [
    `Status: ${escapeHtml(getStatusLabel(input.status))}`,
    `Author: ${escapeHtml(input.authorDisplayName)}`,
    `Attester: ${escapeHtml(input.attesterDisplay)}`,
    `Date signed: ${escapeHtml(input.signedDate)}`,
    input.facilitatorDisplay
      ? `Facilitator: ${escapeHtml(input.facilitatorDisplay)}`
      : '',
    input.dataEntererDisplay
      ? `Data enterer: ${escapeHtml(input.dataEntererDisplay)}`
      : '',
    'Includes advance directive source form PDF.',
  ].filter(Boolean)

  return {
    status: 'generated',
    div: `<div xmlns="http://www.w3.org/1999/xhtml"><p>ADI Portable Medical Order for ${escapeHtml(
      input.patientDisplayName,
    )}.</p><p>${detailParts.join(' ')}</p></div>`,
  } satisfies Composition['text']
}

function buildComposition(
  input: CreateAdiPmoBundleInput,
  sourceFormBinary: Binary,
): Composition {
  const patientDisplayName = getPatientDisplayName(input.patient)
  const authorDisplayName = getPractitionerRoleDisplayName(
    input.practitionerRole,
    input.practitionerByReference,
  )
  const versionNumber = formatAdiVersionNumber(input.createdAt)

  return {
    resourceType: 'Composition',
    meta: {
      profile: [ADI_PMO_COMPOSITION_PROFILE],
    },
    identifier: {
      system: ADI_DOCUMENT_IDENTIFIER_SYSTEM,
      value: crypto.randomUUID(),
    },
    language: 'en-US',
    text: buildCompositionNarrative({
      patientDisplayName,
      authorDisplayName,
      attesterDisplay: input.attester.display,
      signedDate: input.signedDate,
      status: input.status,
      facilitatorDisplay: input.facilitator?.display,
      dataEntererDisplay: input.dataEnterer?.display,
    }),
    extension: [
      {
        url: ADI_DOC_VERSION_EXTENSION_URL,
        valueString: versionNumber,
      },
      ...(input.dataEnterer
        ? [
            {
              url: ADI_DATA_ENTERER_EXTENSION_URL,
              valueReference: {
                reference: input.dataEnterer.reference,
                display: input.dataEnterer.display,
              },
            },
          ]
        : []),
    ],
    status: input.status,
    type: createPmoType(),
    category: [createClinicalNoteCategory(), createAhdCategory()],
    subject: {
      reference: `Patient/${input.patient.id}`,
      display: patientDisplayName,
    },
    date: input.createdAt,
    author: [
      {
        reference: `PractitionerRole/${input.practitionerRole.id}`,
        display: authorDisplayName,
      },
    ],
    title: `ADI POLST PMO for ${patientDisplayName}`,
    attester: [
      {
        mode: 'legal',
        time: input.signedDate,
        party: {
          reference: input.attester.reference,
          display: input.attester.display,
        },
      },
    ],
    ...(input.custodian ? { custodian: input.custodian } : {}),
    ...(input.facilitator
      ? {
          event: [
            {
              code: [
                {
                  coding: [ACP_SERVICES_CODE],
                  text: ACP_SERVICES_CODE.display,
                },
              ],
              detail: [input.facilitator],
            },
          ],
        }
      : {}),
    section: [
      {
        title: 'Advance directive source form',
        code: {
          coding: [
            {
              system: ADI_TEMP_CODE_SYSTEM,
              code: 'advance_directive_source_form',
              display: 'Advance directive source form',
            },
          ],
          text: 'Advance directive source form',
        },
        text: {
          status: 'generated',
          div: `<div xmlns="http://www.w3.org/1999/xhtml"><p>Attached source form PDF for ${escapeHtml(
            patientDisplayName,
          )}</p></div>`,
        },
        entry: [
          {
            reference: `${sourceFormBinary.resourceType}/${sourceFormBinary.id}`,
          },
        ],
      },
      {
        title: 'Portable Medical Orders',
        code: createPmoType(),
        text: {
          status: 'generated',
          div: `<div xmlns="http://www.w3.org/1999/xhtml"><p>Minimal structured PMO metadata for ${escapeHtml(
            patientDisplayName,
          )}. Author: ${escapeHtml(authorDisplayName)}. Attester: ${escapeHtml(
            input.attester.display,
          )}. Signed: ${escapeHtml(input.signedDate)}${
            input.facilitator?.display
              ? `. Facilitator: ${escapeHtml(input.facilitator.display)}`
              : ''
          }${
            input.dataEnterer?.display
              ? `. Data enterer: ${escapeHtml(input.dataEnterer.display)}`
              : ''
          }.</p></div>`,
        },
      },
    ],
  }
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

export function buildAdiPmoBundle(input: CreateAdiPmoBundleInput): Bundle {
  const sourceFormBinary = buildSourceFormBinary(input)
  const composition = buildComposition(input, sourceFormBinary)
  const entries: BundleEntry[] = [
    {
      fullUrl: `urn:uuid:${crypto.randomUUID()}`,
      resource: composition,
    },
    {
      fullUrl: `${sourceFormBinary.resourceType}/${sourceFormBinary.id}`,
      resource: sourceFormBinary,
    },
  ]

  const referencesToInclude = new Set<string>([
    `Patient/${input.patient.id}`,
    `PractitionerRole/${input.practitionerRole.id}`,
    input.attester.reference,
    ...(input.facilitator?.reference ? [input.facilitator.reference] : []),
    ...(input.dataEnterer?.reference ? [input.dataEnterer.reference] : []),
  ])

  const practitionerReference = input.practitionerRole.practitioner?.reference
  if (practitionerReference) {
    referencesToInclude.add(practitionerReference)
  }

  const additionalResources: Resource[] = []

  additionalResources.push(input.patient)
  additionalResources.push(input.practitionerRole)

  if (practitionerReference) {
    const practitioner = input.practitionerByReference.get(practitionerReference)
    if (practitioner) {
      additionalResources.push(practitioner)
    }
  }

  for (const resource of additionalResources) {
    if (!resource.id) continue

    const reference = `${resource.resourceType}/${resource.id}`
    if (!referencesToInclude.has(reference)) continue

    entries.push({
      fullUrl: reference,
      resource,
    })
  }

  return {
    resourceType: 'Bundle',
    type: 'document',
    timestamp: input.createdAt,
    entry: entries,
  }
}

export async function buildClosedAdiPmoBundle(
  baseUrl: string,
  input: CreateAdiPmoBundleInput,
) {
  const initialBundle = buildAdiPmoBundle(input)
  const closedBundle = await closeBundleReferences(baseUrl, initialBundle)
  return withUrnUuidBundleReferences(closedBundle)
}

export async function writeAdiPmoBundle(baseUrl: string, bundle: Bundle) {
  return createBundle(baseUrl, bundle)
}
