import type {
  CodeableConcept,
  DocumentReference,
  Identifier,
  Period,
  Reference,
} from 'fhir/r4'
import { createDocumentReference } from '../lib/fhir/client'

type CreateServerDocumentReferenceInput = {
  baseUrl: string
  subject: Reference
  author: Reference[]
  authenticator?: Reference
  type: CodeableConcept
  category?: CodeableConcept[]
  contentUrl: string
  contentType: string
  docStatus: DocumentReference['docStatus']
  description: string
  version?: string
  createdAt: string
  authenticationTime?: string
  profileUrls?: string[]
  custodian?: Reference
  identifier?: Identifier[]
  masterIdentifier?: Identifier
  jurisdiction?: CodeableConcept
  contextPeriod?: Period
}

const ADI_DOC_VERSION_EXTENSION_URL =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-docVersionNumber-extension'
const ADI_JURISDICTION_EXTENSION_URL =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-jurisdiction-extension'
const US_CORE_AUTHENTICATION_TIME_EXTENSION_URL =
  'http://hl7.org/fhir/us/core/StructureDefinition/us-core-authentication-time'

export function buildDocumentBundleReference(input: {
  pdfBase64: string
  createdAt: string
  patientReference: string
}): DocumentReference {
  return {
    resourceType: 'DocumentReference',
    status: 'current',
    docStatus: 'final',
    type: {
      coding: [
        {
          system: 'http://loinc.org',
          code: '93037-0',
          display: 'Portable medical order form',
        },
      ],
      text: 'Portable medical order form',
    },
    category: [
      {
        coding: [
          {
            system: 'http://loinc.org',
            code: '42348-3',
            display: 'Advance healthcare directives',
          },
        ],
        text: 'Advance healthcare directives',
      },
    ],
    subject: {
      reference: input.patientReference,
    },
    date: input.createdAt,
    content: [
      {
        attachment: {
          contentType: 'application/pdf',
          data: input.pdfBase64,
          creation: input.createdAt,
          title: 'ADI POLST PMO source form',
        },
      },
    ],
  }
}

export function buildServerDocumentReference(
  input: Omit<CreateServerDocumentReferenceInput, 'baseUrl'>,
): DocumentReference {
  const extension = [
    ...(input.authenticationTime
      ? [
          {
            url: US_CORE_AUTHENTICATION_TIME_EXTENSION_URL,
            valueDateTime: input.authenticationTime,
          },
        ]
      : []),
    ...(input.version
      ? [
          {
            url: ADI_DOC_VERSION_EXTENSION_URL,
            valueString: input.version,
          },
        ]
      : []),
    ...(input.jurisdiction
      ? [
          {
            url: ADI_JURISDICTION_EXTENSION_URL,
            valueCodeableConcept: input.jurisdiction,
          },
        ]
      : []),
  ]

  const context =
    input.contextPeriod
      ? {
          period: input.contextPeriod,
        }
      : undefined

  return {
    resourceType: 'DocumentReference',
    ...(input.profileUrls && input.profileUrls.length > 0
      ? {
          meta: {
            profile: input.profileUrls,
          },
        }
      : {}),
    status: 'current',
    docStatus: input.docStatus,
    ...(extension.length > 0 ? { extension } : {}),
    ...(input.masterIdentifier ? { masterIdentifier: input.masterIdentifier } : {}),
    ...(input.identifier ? { identifier: input.identifier } : {}),
    type: input.type,
    ...(input.category ? { category: input.category } : {}),
    subject: input.subject,
    author: input.author,
    ...(input.authenticator ? { authenticator: input.authenticator } : {}),
    ...(input.custodian ? { custodian: input.custodian } : {}),
    date: input.createdAt,
    description: input.description,
    ...(context ? { context } : {}),
    content: [
      {
        attachment: {
          contentType: input.contentType,
          url: input.contentUrl,
          creation: input.createdAt,
        },
      },
    ],
  }
}

export async function writeServerDocumentReference(
  input: CreateServerDocumentReferenceInput,
) {
  const documentReference = buildServerDocumentReference({
    subject: input.subject,
    author: input.author,
    authenticator: input.authenticator,
    type: input.type,
    category: input.category,
    contentUrl: input.contentUrl,
    contentType: input.contentType,
    docStatus: input.docStatus,
    description: input.description,
    version: input.version,
    createdAt: input.createdAt,
    authenticationTime: input.authenticationTime,
    profileUrls: input.profileUrls,
    custodian: input.custodian,
    identifier: input.identifier,
    masterIdentifier: input.masterIdentifier,
    jurisdiction: input.jurisdiction,
    contextPeriod: input.contextPeriod,
  })

  return createDocumentReference(input.baseUrl, documentReference)
}
