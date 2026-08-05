import { useEffect, useMemo, useState } from 'react'
import { fetchPatients } from '../../lib/fhir/client'
import { navigateTo } from '../../lib/routing/routes'
import { useSavedServers } from '../servers/useSavedServers'
import { buildPatientListItems, filterPatients } from './patientListModel'

export function PatientListPage() {
  const { activeServer } = useSavedServers()
  const [search, setSearch] = useState('')
  const [patients, setPatients] = useState<ReturnType<typeof buildPatientListItems>>([])
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  useEffect(() => {
    if (!activeServer) {
      return
    }

    let isMounted = true
    setIsLoading(true)
    setErrorMessage('')

    console.log(`Connecting to FHIR server ${activeServer.label} (${activeServer.baseUrl})`)

    fetchPatients(activeServer.baseUrl, 100)
      .then((bundle) => {
        if (!isMounted) return

        const patientItems = buildPatientListItems(bundle)
        setPatients(patientItems)

        console.log(`${patientItems.length} patient records returned`)
      })
      .catch((error) => {
        if (!isMounted) return
        setErrorMessage(
          error instanceof Error ? error.message : 'Unable to load patients.',
        )

        console.error('Failed to load patients from FHIR server.', error)
      })
      .finally(() => {
        if (!isMounted) return
        setIsLoading(false)
      })

    return () => {
      isMounted = false
    }
  }, [activeServer])

  const visiblePatients = useMemo(
    () => filterPatients(patients, search),
    [patients, search],
  )

  if (!activeServer) {
    return null
  }

  return (
    <section className="panel">
      <div className="panel-header">
        <div>
          <h2>Browse patients — {patients.length} available</h2>
        </div>

        <div className="panel-server-details">
          <span className="panel-server-label">{activeServer.label}</span>
          <span className="panel-server-url">{activeServer.baseUrl}</span>
        </div>
      </div>

      <div className="patient-list-panel full-width-panel">
        <div className="field-group patient-search-group">
          <label htmlFor="patient-search">Search patients</label>
          <input
            id="patient-search"
            type="text"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by name, DOB, or MRN"
          />
        </div>

        {isLoading ? <div className="info-banner">Loading patients...</div> : null}

        {errorMessage ? <div className="error-banner">{errorMessage}</div> : null}

        {!isLoading && !errorMessage ? (
          visiblePatients.length > 0 ? (
            <ul className="patient-list full-width-patient-list">
              {visiblePatients.map((patient) => (
                <li key={patient.id} className="patient-list-item">
                  <button
                    type="button"
                    className="patient-select-button"
                    onClick={() => navigateTo(`/patients/${patient.id}`)}
                  >
                    <span className="patient-list-content">
                      <span className="patient-name">{patient.name}</span>
                      <span className="patient-meta">
                        {patient.gender} · DOB {patient.dob}
                      </span>
                      <span className="patient-meta">MRN {patient.mrn}</span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="empty-state">No matching patients found.</p>
          )
        ) : null}
      </div>
    </section>
  )
}
