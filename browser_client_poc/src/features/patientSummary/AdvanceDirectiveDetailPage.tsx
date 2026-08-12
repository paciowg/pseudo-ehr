import { useEffect, useMemo, useState } from 'react'
import type { Attachment, CodeableConcept, DocumentReference, Identifier, Reference } from 'fhir/r4'
import { fetchDocumentReference, fetchPatient } from '../../lib/fhir/client'
import {
  formatDate,
  getCodeableConceptText,
  getDisplayNameFromHumanName,
  placeholderValue,
} from '../../lib/fhir/formatters'
import { navigateTo } from '../../lib/routing/routes'
import { useSavedServers } from '../servers/useSavedServers'

type AdvanceDirectiveDetailPageProps = {
  patientId: string
  documentReferenceId: string
}

type DetailRow = {
  label: string
  value: string
}

function joinValues(values: string[]) {
  return values.filter(Boolean).join(', ')
}

function formatReference(reference: Reference | undefined) {
  if (!reference) return placeholderValue()
  return reference.display || reference.reference || placeholderValue()
}

function formatReferences(references: Reference[] | undefined) {
  if (!references || references.length === 0) return placeholderValue()

  const values = references
    .map((reference) => formatReference(reference))
    .filter((value) => value !== placeholderValue())

  return values.length > 0 ? values.join(', ') : placeholderValue()
}

function formatCodeableConcepts(concepts: CodeableConcept[] | undefined) {
  if (!concepts || concepts.length === 0) return placeholderValue()

  const values = concepts
    .map((concept) => getCodeableConceptText(concept))
    .filter(Boolean)

  return values.length > 0 ? values.join(', ') : placeholderValue()
}

function formatIdentifiers(identifiers: Identifier[] | undefined) {
  if (!identifiers || identifiers.length === 0) return placeholderValue()

  const values = identifiers
    .map((identifier) =>
      joinValues(
        [identifier.system, identifier.value].filter(
          (value): value is string => Boolean(value),
        ),
      ),
    )
    .filter(Boolean)

  return values.length > 0 ? values.join(', ') : placeholderValue()
}

function formatAttachment(attachment: Attachment | undefined) {
  if (!attachment) return placeholderValue()

  const values = [
    attachment.title,
    attachment.contentType,
    attachment.url,
    attachment.creation ? `Created ${formatDate(attachment.creation)}` : '',
  ].filter(Boolean)

  return values.length > 0 ? values.join(' · ') : placeholderValue()
}

function formatAttachments(content: DocumentReference['content'] | undefined) {
  if (!content || content.length === 0) return placeholderValue()

  const values = content
    .map((item) => formatAttachment(item.attachment))
    .filter((value) => value !== placeholderValue())

  return values.length > 0 ? values.join('\n') : placeholderValue()
}

function formatContextPeriod(documentReference: DocumentReference) {
  const start = documentReference.context?.period?.start
  const end = documentReference.context?.period?.end

  if (!start && !end) return placeholderValue()
  if (start && end) return `${formatDate(start)} to ${formatDate(end)}`
  if (start) return `From ${formatDate(start)}`
  return `Through ${formatDate(end)}`
}

function formatSecurityLabels(documentReference: DocumentReference) {
  return formatCodeableConcepts(documentReference.securityLabel)
}

function buildDetailRows(documentReference: DocumentReference): DetailRow[] {
  return [
    { label: 'Id', value: documentReference.id || placeholderValue() },
    { label: 'Status', value: documentReference.status || placeholderValue() },
    { label: 'Document status', value: documentReference.docStatus || placeholderValue() },
    {
      label: 'Type',
      value: getCodeableConceptText(documentReference.type) || placeholderValue(),
    },
    {
      label: 'Category',
      value: formatCodeableConcepts(documentReference.category),
    },
    {
      label: 'Subject',
      value: formatReference(documentReference.subject),
    },
    {
      label: 'Author',
      value: formatReferences(documentReference.author),
    },
    {
      label: 'Custodian',
      value: formatReference(documentReference.custodian),
    },
    {
      label: 'Date',
      value: formatDate(documentReference.date),
    },
    {
      label: 'Description',
      value: documentReference.description || placeholderValue(),
    },
    {
      label: 'Master identifier',
      value: formatIdentifiers(
        documentReference.masterIdentifier
          ? [documentReference.masterIdentifier]
          : undefined,
      ),
    },
    {
      label: 'Identifier(s)',
      value: formatIdentifiers(documentReference.identifier),
    },
    {
      label: 'Context period',
      value: formatContextPeriod(documentReference),
    },
    {
      label: 'Security label',
      value: formatSecurityLabels(documentReference),
    },
    {
      label: 'Content',
      value: formatAttachments(documentReference.content),
    },
  ]
}

export function AdvanceDirectiveDetailPage({
  patientId,
  documentReferenceId,
}: AdvanceDirectiveDetailPageProps) {
  const { activeServer } = useSavedServers()
  const [patientName, setPatientName] = useState('')
  const [documentReference, setDocumentReference] = useState<DocumentReference | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  useEffect(() => {
    if (!activeServer) {
      navigateTo('/')
      return
    }

    let isMounted = true
    setIsLoading(true)
    setErrorMessage('')

    async function load() {
      try {
        const [patient, loadedDocumentReference] = await Promise.all([
          fetchPatient(activeServer.baseUrl, patientId),
          fetchDocumentReference(activeServer.baseUrl, documentReferenceId),
        ])

        if (!isMounted) return

        setPatientName(
          getDisplayNameFromHumanName(patient.name?.[0]) || patient.id || placeholderValue(),
        )
        setDocumentReference(loadedDocumentReference)
      } catch (error) {
        if (!isMounted) return

        setErrorMessage(
          error instanceof Error
            ? error.message
            : 'Unable to load the advance directive.',
        )
      } finally {
        if (!isMounted) return
        setIsLoading(false)
      }
    }

    void load()

    return () => {
      isMounted = false
    }
  }, [activeServer, patientId, documentReferenceId])

  const detailRows = useMemo(
    () => (documentReference ? buildDetailRows(documentReference) : []),
    [documentReference],
  )

  if (!activeServer) {
    return null
  }

  return (
    <section className="panel">
      <div className="panel-header">
        <div>
          <h2>Advance Directive</h2>
        </div>

        <div className="panel-server-details">
          <span className="panel-server-label">{activeServer.label}</span>
          <span className="panel-server-url">{activeServer.baseUrl}</span>
        </div>
      </div>

      <div className="summary-preview-panel full-width-panel">
        <div className="page-actions page-actions-spaced">
          <button
            type="button"
            className="secondary-button outline"
            onClick={() => navigateTo(`/patients/${patientId}`)}
          >
            Back to patient
          </button>
        </div>

        {isLoading ? <div className="info-banner">Loading advance directive...</div> : null}
        {errorMessage ? <div className="error-banner">{errorMessage}</div> : null}

        {!isLoading && !errorMessage && documentReference ? (
          <>
            <section className="patient-summary-hero">
              <div>
                <p className="patient-summary-name">
                  {getCodeableConceptText(documentReference.type) || 'Advance Directive'}
                </p>
                <p className="patient-summary-meta">
                  {patientName} · Date {formatDate(documentReference.date)} · DocumentReference/{documentReference.id}
                </p>
              </div>
            </section>

            <section className="summary-card wide">
              <h3>DocumentReference Details</h3>
              <dl className="stacked-details detail-list">
                {detailRows.map((row) => (
                  <div key={row.label}>
                    <dt>{row.label}</dt>
                    <dd className="preformatted-detail">{row.value}</dd>
                  </div>
                ))}
              </dl>
            </section>
          </>
        ) : null}
      </div>
    </section>
  )
}
