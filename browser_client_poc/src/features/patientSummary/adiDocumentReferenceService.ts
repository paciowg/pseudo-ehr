import type { CodeableConcept, DocumentReference, Reference } from 'fhir/r4'
import { createDocumentReference } from '../../lib/fhir/client'

type CreateServerDocumentReferenceInput = {
  baseUrl: string
  subject: Reference
  author: Reference[]
  type: CodeableConcept
  category?: CodeableConcept[]
  contentUrl: string
  contentType: string
  docStatus: DocumentReference['docStatus']
  description: string
  version?: string
  createdAt: string
}

const ADI_DOC_VERSION_EXTENSION_URL =
  'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-docVersionNumber-extension'

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
  return {
    resourceType: 'DocumentReference',
    status: 'current',
    docStatus: input.docStatus,
    ...(input.version
      ? {
          extension: [
            {
              url: ADI_DOC_VERSION_EXTENSION_URL,
              valueString: input.version,
            },
          ],
        }
      : {}),
    type: input.type,
    ...(input.category ? { category: input.category } : {}),
    subject: input.subject,
    author: input.author,
    date: input.createdAt,
    description: input.description,
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
    type: input.type,
    category: input.category,
    contentUrl: input.contentUrl,
    contentType: input.contentType,
    docStatus: input.docStatus,
    description: input.description,
    version: input.version,
    createdAt: input.createdAt,
  })

  return createDocumentReference(input.baseUrl, documentReference)
}
