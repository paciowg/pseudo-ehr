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

export type CreateAdiPmoBundleInput = {
  patient: Patient
  practitionerRole: PractitionerRole
  practitionerByReference: Map<string, Practitioner>
  attester: PmoAttesterOption
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
const ADI_TEMP_CODE_SYSTEM = 'http://hl7.org/fhir/us/pacio-adi/CodeSystem/ADITempCS'
const ADI_DOCUMENT_IDENTIFIER_SYSTEM =
  'https://pacioproject.org/adi-document-identifier'

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
    id: 'source-form-binary',
    meta: {
      profile: [ADI_SOURCE_FORM_BINARY_PROFILE],
    },
    contentType: 'application/pdf',
    data: input.pdfBase64,
  }
}

function buildComposition(input: CreateAdiPmoBundleInput): Composition {
  const patientDisplayName = getPatientDisplayName(input.patient)
  const authorDisplayName = getPractitionerRoleDisplayName(
    input.practitionerRole,
    input.practitionerByReference,
  )
  const versionNumber = formatAdiVersionNumber(input.createdAt)
  const sourceFormBinary = buildSourceFormBinary(input)

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
    extension: [
      {
        url: ADI_DOC_VERSION_EXTENSION_URL,
        valueString: versionNumber,
      },
    ],
    status: input.status,
    type: createPmoType(),
    category: [createAhdCategory()],
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
            reference: '#source-form-binary',
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
          )}. Signed: ${escapeHtml(input.signedDate)}.</p></div>`,
        },
      },
    ],
    contained: [sourceFormBinary],
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
  const composition = buildComposition(input)
  const entries: BundleEntry[] = [
    {
      fullUrl: `urn:uuid:${crypto.randomUUID()}`,
      resource: composition,
    },
  ]

  const referencesToInclude = new Set<string>([
    `Patient/${input.patient.id}`,
    `PractitionerRole/${input.practitionerRole.id}`,
    input.attester.reference,
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
