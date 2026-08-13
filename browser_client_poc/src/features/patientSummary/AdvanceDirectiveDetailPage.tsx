import { useEffect, useMemo, useState } from 'react'
import type {
  Attachment,
  Binary,
  Bundle,
  BundleEntry,
  CodeableConcept,
  Composition,
  DocumentReference,
  Identifier,
  Reference,
  Resource,
} from 'fhir/r4'
import {
  fetchBundleByReference,
  fetchDocumentReference,
  fetchPatient,
} from '../../lib/fhir/client'
import {
  formatDate,
  getCodeableConceptText,
  getDisplayNameFromHumanName,
  placeholderValue,
} from '../../lib/fhir/formatters'
import { navigateTo } from '../../lib/routing/routes'
import { normalizeBaseUrl } from '../servers/serverStorage'
import { useSavedServers } from '../servers/useSavedServers'

type AdvanceDirectiveDetailPageProps = {
  patientId: string
  documentReferenceId: string
}

type DetailRow = {
  label: string
  value: string
}

type AttachmentViewer = {
  label: string
  open: () => void
}

type BundleDerivedData = {
  composition: Composition
  rows: DetailRow[]
  sections: {
    title: string
    code: string
    text: string
  }[]
  pdfViewers: AttachmentViewer[]
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

function buildDocumentReferenceRows(documentReference: DocumentReference): DetailRow[] {
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

function buildBundleEntryMaps(bundle: Bundle) {
  const entryByFullUrl = new Map<string, BundleEntry>()
  const entryByReference = new Map<string, BundleEntry>()
  const containedById = new Map<string, Resource>()

  for (const entry of bundle.entry ?? []) {
    if (entry.fullUrl) {
      entryByFullUrl.set(entry.fullUrl, entry)
    }

    const resource = entry.resource
    if (resource?.resourceType && resource.id) {
      entryByReference.set(`${resource.resourceType}/${resource.id}`, entry)
    }

    const containedResources = (resource as Resource & { contained?: Resource[] })?.contained ?? []
    for (const contained of containedResources) {
      if (contained.id) {
        containedById.set(`#${contained.id}`, contained)
      }
    }
  }

  return { entryByFullUrl, entryByReference, containedById }
}

function resolveBundleResource(
  bundle: Bundle,
  reference: string | undefined,
): Resource | undefined {
  if (!reference) return undefined

  const { entryByFullUrl, entryByReference, containedById } = buildBundleEntryMaps(bundle)

  if (reference.startsWith('#')) {
    return containedById.get(reference)
  }

  if (entryByFullUrl.has(reference)) {
    return entryByFullUrl.get(reference)?.resource
  }

  if (entryByReference.has(reference)) {
    return entryByReference.get(reference)?.resource
  }

  const normalizedReference = reference.replace(/^https?:\/\/[^/]+\//, '')
  if (entryByReference.has(normalizedReference)) {
    return entryByReference.get(normalizedReference)?.resource
  }

  return undefined
}

function getDocumentComposition(bundle: Bundle) {
  return (
    bundle.entry
      ?.map((entry) => entry.resource)
      .find((resource): resource is Composition => resource?.resourceType === 'Composition') ||
    null
  )
}

function normalizeDivText(value: string | undefined) {
  if (!value) return placeholderValue()

  return value
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim() || placeholderValue()
}

function buildBundleDerivedRows(bundle: Bundle, composition: Composition): DetailRow[] {
  return [
    { label: 'Bundle id', value: bundle.id || placeholderValue() },
    { label: 'Bundle type', value: bundle.type || placeholderValue() },
    { label: 'Composition id', value: composition.id || placeholderValue() },
    { label: 'Status', value: composition.status || placeholderValue() },
    { label: 'Title', value: composition.title || placeholderValue() },
    {
      label: 'Type',
      value: getCodeableConceptText(composition.type) || placeholderValue(),
    },
    {
      label: 'Category',
      value: formatCodeableConcepts(composition.category),
    },
    {
      label: 'Subject',
      value: formatReference(composition.subject),
    },
    {
      label: 'Author',
      value: formatReferences(composition.author),
    },
    {
      label: 'Attester',
      value:
        composition.attester && composition.attester.length > 0
          ? composition.attester
              .map((attester) =>
                joinValues(
                  [
                    attester.mode || '',
                    attester.party?.display || attester.party?.reference || '',
                    attester.time ? formatDate(attester.time) : '',
                  ].filter(Boolean),
                ),
              )
              .join(', ')
          : placeholderValue(),
    },
    {
      label: 'Custodian',
      value: formatReference(composition.custodian),
    },
    {
      label: 'Date',
      value: formatDate(composition.date),
    },
    {
      label: 'Identifier',
      value: formatIdentifiers(composition.identifier ? [composition.identifier] : undefined),
    },
  ]
}

function getBundleSections(composition: Composition) {
  return (composition.section ?? []).map((section, index) => ({
    title: section.title || `Section ${index + 1}`,
    code: getCodeableConceptText(section.code) || placeholderValue(),
    text: normalizeDivText(section.text?.div),
  }))
}

function createBlobUrlViewer(label: string, mimeType: string, byteCharacters: string) {
  return {
    label,
    open: () => {
      const bytes = Uint8Array.from(byteCharacters, (character) => character.charCodeAt(0))
      const blob = new Blob([bytes], { type: mimeType })
      const blobUrl = window.URL.createObjectURL(blob)
      window.open(blobUrl, '_blank', 'noopener,noreferrer')
      window.setTimeout(() => {
        window.URL.revokeObjectURL(blobUrl)
      }, 60_000)
    },
  } satisfies AttachmentViewer
}

function createAttachmentViewer(
  label: string,
  attachment: Attachment,
): AttachmentViewer | null {
  const contentType = attachment.contentType || ''
  if (contentType !== 'application/pdf') return null

  if (attachment.data) {
    try {
      return createBlobUrlViewer(label, contentType, atob(attachment.data))
    } catch {
      return null
    }
  }

  if (attachment.url) {
    return {
      label,
      open: () => {
        window.open(attachment.url!, '_blank', 'noopener,noreferrer')
      },
    }
  }

  return null
}

function createBinaryViewer(label: string, binary: Binary): AttachmentViewer | null {
  if (binary.contentType !== 'application/pdf' || !binary.data) return null

  try {
    return createBlobUrlViewer(label, binary.contentType, atob(binary.data))
  } catch {
    return null
  }
}

function getBundlePdfViewers(bundle: Bundle, composition: Composition) {
  const viewers: AttachmentViewer[] = []
  const seenLabels = new Set<string>()

  for (const section of composition.section ?? []) {
    for (const entry of section.entry ?? []) {
      const resource = resolveBundleResource(bundle, entry.reference)

      if (resource?.resourceType === 'Binary') {
        const viewer = createBinaryViewer(section.title || 'View PDF', resource)
        if (viewer && !seenLabels.has(viewer.label)) {
          viewers.push(viewer)
          seenLabels.add(viewer.label)
        }
      }

      if (resource?.resourceType === 'DocumentReference') {
        for (const contentItem of resource.content ?? []) {
          const viewer = createAttachmentViewer(
            contentItem.attachment?.title || section.title || 'View PDF',
            contentItem.attachment,
          )
          if (viewer && !seenLabels.has(viewer.label)) {
            viewers.push(viewer)
            seenLabels.add(viewer.label)
          }
        }
      }

      if (resource) {
        const containedResources = (resource as Resource & { contained?: Resource[] }).contained ?? []

        for (const contained of containedResources) {
          if (contained.resourceType === 'Binary') {
            const viewer = createBinaryViewer(section.title || 'View PDF', contained)
            if (viewer && !seenLabels.has(viewer.label)) {
              viewers.push(viewer)
              seenLabels.add(viewer.label)
            }
          }
        }
      }
    }
  }

  return viewers
}

function getReferencedBundleUrl(documentReference: DocumentReference, baseUrl: string) {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl)

  for (const contentItem of documentReference.content ?? []) {
    const url = contentItem.attachment?.url?.trim()
    if (!url) continue

    if (url.startsWith('Bundle/')) {
      return url
    }

    if (url.startsWith('/Bundle/')) {
      return url.slice(1)
    }

    if (url.startsWith(`${normalizedBaseUrl}/Bundle/`)) {
      return url
    }
  }

  return ''
}

function buildBundleDerivedData(bundle: Bundle): BundleDerivedData | null {
  const composition = getDocumentComposition(bundle)
  if (!composition) return null

  return {
    composition,
    rows: buildBundleDerivedRows(bundle, composition),
    sections: getBundleSections(composition),
    pdfViewers: getBundlePdfViewers(bundle, composition),
  }
}

export function AdvanceDirectiveDetailPage({
  patientId,
  documentReferenceId,
}: AdvanceDirectiveDetailPageProps) {
  const { activeServer } = useSavedServers()
  const [patientName, setPatientName] = useState('')
  const [documentReference, setDocumentReference] = useState<DocumentReference | null>(null)
  const [bundleDerivedData, setBundleDerivedData] = useState<BundleDerivedData | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [bundleWarningMessage, setBundleWarningMessage] = useState('')

  useEffect(() => {
    if (!activeServer) {
      navigateTo('/')
      return
    }

    let isMounted = true
    setIsLoading(true)
    setErrorMessage('')
    setBundleWarningMessage('')
    setBundleDerivedData(null)

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

        const bundleReference = getReferencedBundleUrl(
          loadedDocumentReference,
          activeServer.baseUrl,
        )

        if (!bundleReference) {
          return
        }

        try {
          const bundle = await fetchBundleByReference(activeServer.baseUrl, bundleReference)
          if (!isMounted) return

          const derivedData = buildBundleDerivedData(bundle)

          if (derivedData) {
            setBundleDerivedData(derivedData)
          } else {
            setBundleWarningMessage(
              'A Bundle was referenced, but no Composition was found. Showing DocumentReference details.',
            )
          }
        } catch (bundleError) {
          if (!isMounted) return

          setBundleWarningMessage(
            bundleError instanceof Error
              ? `Unable to load referenced Bundle. ${bundleError.message}`
              : 'Unable to load referenced Bundle. Showing DocumentReference details.',
          )
        }
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

  const documentReferenceRows = useMemo(
    () => (documentReference ? buildDocumentReferenceRows(documentReference) : []),
    [documentReference],
  )

  if (!activeServer) {
    return null
  }

  const pageTitle =
    bundleDerivedData?.composition.title ||
    getCodeableConceptText(bundleDerivedData?.composition.type) ||
    getCodeableConceptText(documentReference?.type) ||
    'Advance Directive'

  const pageDate =
    bundleDerivedData?.composition.date ||
    documentReference?.date

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
        {bundleWarningMessage ? <div className="warning-banner">{bundleWarningMessage}</div> : null}
        {errorMessage ? <div className="error-banner">{errorMessage}</div> : null}

        {!isLoading && !errorMessage && documentReference ? (
          <>
            <section className="patient-summary-hero">
              <div>
                <p className="patient-summary-name">{pageTitle}</p>
                <p className="patient-summary-meta">
                  {patientName} · Date {formatDate(pageDate)} · DocumentReference/{documentReference.id}
                </p>
              </div>
            </section>

            {bundleDerivedData ? (
              <>
                {bundleDerivedData.pdfViewers.length > 0 ? (
                  <section className="summary-card wide">
                    <h3>Source Attachments</h3>
                    <div className="attachment-actions">
                      {bundleDerivedData.pdfViewers.map((viewer) => (
                        <button
                          key={viewer.label}
                          type="button"
                          className="secondary-button outline"
                          onClick={viewer.open}
                        >
                          {viewer.label}
                        </button>
                      ))}
                    </div>
                  </section>
                ) : null}

                <section className="summary-card wide">
                  <h3>Document Bundle Details</h3>
                  <dl className="stacked-details detail-list">
                    {bundleDerivedData.rows.map((row) => (
                      <div key={row.label}>
                        <dt>{row.label}</dt>
                        <dd className="preformatted-detail">{row.value}</dd>
                      </div>
                    ))}
                  </dl>
                </section>

                {bundleDerivedData.sections.length > 0 ? (
                  <section className="summary-card wide">
                    <h3>Composition Sections</h3>
                    <div className="bundle-sections">
                      {bundleDerivedData.sections.map((section) => (
                        <article
                          key={`${section.title}-${section.code}`}
                          className="bundle-section-card"
                        >
                          <h4>{section.title}</h4>
                          <p className="bundle-section-code">{section.code}</p>
                          <p className="bundle-section-text">{section.text}</p>
                        </article>
                      ))}
                    </div>
                  </section>
                ) : null}

                <section className="summary-card wide">
                  <h3>DocumentReference Details</h3>
                  <p className="helper-text">
                    Bundle and Composition values are shown above when available. The original
                    DocumentReference is shown here for reference.
                  </p>
                  <dl className="stacked-details detail-list">
                    {documentReferenceRows.map((row) => (
                      <div key={row.label}>
                        <dt>{row.label}</dt>
                        <dd className="preformatted-detail">{row.value}</dd>
                      </div>
                    ))}
                  </dl>
                </section>
              </>
            ) : (
              <section className="summary-card wide">
                <h3>DocumentReference Details</h3>
                <dl className="stacked-details detail-list">
                  {documentReferenceRows.map((row) => (
                    <div key={row.label}>
                      <dt>{row.label}</dt>
                      <dd className="preformatted-detail">{row.value}</dd>
                    </div>
                  ))}
                </dl>
              </section>
            )}
          </>
        ) : null}
      </div>
    </section>
  )
}
