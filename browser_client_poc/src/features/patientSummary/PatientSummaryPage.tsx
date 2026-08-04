import { useEffect, useState } from 'react'
import { ClinicalSummarySection } from '../../components/ClinicalSummarySection'
import { fetchPatient, fetchPatientEverything } from '../../lib/fhir/client'
import { navigateTo } from '../../lib/routing/routes'
import { useSavedServers } from '../servers/useSavedServers'
import { buildPatientSummaryModel, type PatientSummaryModel } from './patientSummaryModel'

type PatientSummaryPageProps = {
  patientId: string
}

export function PatientSummaryPage({ patientId }: PatientSummaryPageProps) {
  const { activeServer } = useSavedServers()
  const [summary, setSummary] = useState<PatientSummaryModel | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [fallbackMessage, setFallbackMessage] = useState('')

  useEffect(() => {
    if (!activeServer) {
      navigateTo('/')
      return
    }

    let isMounted = true
    setIsLoading(true)
    setErrorMessage('')
    setFallbackMessage('')

    async function load() {
      try {
        const bundle = await fetchPatientEverything(activeServer.baseUrl, patientId)
        const patient =
          bundle.entry
            ?.map((entry) => entry.resource)
            .find((resource) => resource?.resourceType === 'Patient' && resource.id === patientId) ||
          (await fetchPatient(activeServer.baseUrl, patientId))

        if (!isMounted) return

        setSummary(
          buildPatientSummaryModel({
            patient,
            bundle,
            bundleAvailable: true,
          }),
        )
      } catch {
        try {
          const patient = await fetchPatient(activeServer.baseUrl, patientId)
          if (!isMounted) return

          setSummary(
            buildPatientSummaryModel({
              patient,
              bundle: null,
              bundleAvailable: false,
            }),
          )
          setFallbackMessage(
            '$everything was unavailable for this patient. Showing patient-only fallback data.',
          )
        } catch (error) {
          if (!isMounted) return
          setErrorMessage(
            error instanceof Error
              ? error.message
              : 'Unable to load the patient summary.',
          )
        }
      } finally {
        if (!isMounted) return
        setIsLoading(false)
      }
    }

    void load()

    return () => {
      isMounted = false
    }
  }, [activeServer, patientId])

  if (!activeServer) {
    return null
  }

  return (
    <section className="panel">
      <div className="panel-header">
        <div>
          <p className="section-kicker">Step 3</p>
          <h2>Patient summary</h2>
        </div>
        <span className="panel-tag">Route: #/patients/{patientId}</span>
      </div>

      <div className="summary-preview-panel full-width-panel">
        <div className="active-server-banner">
          Active server: <strong>{activeServer.label}</strong> · {activeServer.baseUrl}
        </div>

        <div className="page-actions">
          <button
            type="button"
            className="secondary-button outline"
            onClick={() => navigateTo('/patients')}
          >
            Back to patients
          </button>
          <button
            type="button"
            className="secondary-button outline"
            onClick={() => navigateTo('/')}
          >
            Change server
          </button>
        </div>

        {isLoading ? <div className="info-banner">Loading patient summary...</div> : null}
        {fallbackMessage ? <div className="warning-banner">{fallbackMessage}</div> : null}
        {errorMessage ? <div className="error-banner">{errorMessage}</div> : null}

        {!isLoading && !errorMessage && summary ? (
          <>
            <section className="patient-summary-hero">
              <div>
                <p className="patient-summary-name">{summary.patientName}</p>
                <p className="patient-summary-meta">{summary.patientMeta}</p>
              </div>
              <div className={`bundle-status ${summary.bundleStatusTone}`}>
                {summary.bundleStatusText}
              </div>
            </section>

            <div className="summary-grid">
              <section className="summary-card wide">
                <h3>Personal Information</h3>
                <dl className="detail-grid">
                  <div>
                    <dt>First name</dt>
                    <dd>{summary.personalInformation.firstName}</dd>
                  </div>
                  <div>
                    <dt>Last name</dt>
                    <dd>{summary.personalInformation.lastName}</dd>
                  </div>
                  <div>
                    <dt>Date of birth</dt>
                    <dd>{summary.personalInformation.birthDate}</dd>
                  </div>
                  <div>
                    <dt>Gender identity</dt>
                    <dd>{summary.personalInformation.gender}</dd>
                  </div>
                  <div>
                    <dt>Sex assigned at birth</dt>
                    <dd>{summary.personalInformation.birthSex}</dd>
                  </div>
                  <div>
                    <dt>Marital status</dt>
                    <dd>{summary.personalInformation.maritalStatus}</dd>
                  </div>
                  <div className="span-2">
                    <dt>Medical record number</dt>
                    <dd>{summary.personalInformation.mrn}</dd>
                  </div>
                </dl>
              </section>

              <section className="summary-card">
                <h3>Demographics</h3>
                <dl className="stacked-details">
                  <div>
                    <dt>Race</dt>
                    <dd>{summary.demographics.race}</dd>
                  </div>
                  <div>
                    <dt>Ethnicity</dt>
                    <dd>{summary.demographics.ethnicity}</dd>
                  </div>
                  <div>
                    <dt>Language</dt>
                    <dd>{summary.demographics.language}</dd>
                  </div>
                </dl>
              </section>

              <section className="summary-card">
                <h3>Contact Information</h3>
                <dl className="stacked-details">
                  <div>
                    <dt>Address</dt>
                    <dd>{summary.contactInformation.address}</dd>
                  </div>
                  <div>
                    <dt>Phone</dt>
                    <dd>{summary.contactInformation.phone}</dd>
                  </div>
                  <div>
                    <dt>Email</dt>
                    <dd>{summary.contactInformation.email}</dd>
                  </div>
                </dl>
              </section>

              <section className="summary-card wide">
                <h3>Emergency Contacts</h3>
                {summary.emergencyContacts.length > 0 ? (
                  <div className="contact-cards">
                    {summary.emergencyContacts.map((contact) => (
                      <article
                        key={`${contact.name}-${contact.relationship}-${contact.phone}`}
                        className="contact-card"
                      >
                        <h4>
                          {contact.name} <span>({contact.relationship})</span>
                        </h4>
                        <dl className="stacked-details">
                          <div>
                            <dt>Phone</dt>
                            <dd>{contact.phone}</dd>
                          </div>
                          <div>
                            <dt>Email</dt>
                            <dd>{contact.email}</dd>
                          </div>
                          <div>
                            <dt>Address</dt>
                            <dd>{contact.address}</dd>
                          </div>
                        </dl>
                      </article>
                    ))}
                  </div>
                ) : (
                  <p className="empty-state">None recorded</p>
                )}
              </section>

              <ClinicalSummarySection
                title="Active Problems"
                items={summary.activeProblems}
                emptyMessage={summary.clinicalSectionEmptyMessage}
              />
              <ClinicalSummarySection
                title="Current Medications"
                items={summary.currentMedications}
                emptyMessage={summary.clinicalSectionEmptyMessage}
              />
              <ClinicalSummarySection
                title="Known Allergies"
                items={summary.knownAllergies}
                emptyMessage={summary.clinicalSectionEmptyMessage}
              />
              <ClinicalSummarySection
                title="Most Recent Vitals"
                items={summary.mostRecentVitals}
                emptyMessage={summary.clinicalSectionEmptyMessage}
              />
            </div>
          </>
        ) : null}
      </div>
    </section>
  )
}
