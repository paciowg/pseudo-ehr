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
      navigateTo('/')
      return
    }

    let isMounted = true
    setIsLoading(true)
    setErrorMessage('')

    fetchPatients(activeServer.baseUrl, 100)
      .then((bundle) => {
        if (!isMounted) return
        setPatients(buildPatientListItems(bundle))
      })
      .catch((error) => {
        if (!isMounted) return
        setErrorMessage(
          error instanceof Error ? error.message : 'Unable to load patients.',
        )
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
          <p className="section-kicker">Step 2</p>
          <h2>Browse patients</h2>
        </div>
        <span className="panel-tag">Route: #/patients</span>
      </div>

      <div className="patient-list-panel full-width-panel">
        <div className="active-server-banner">
          Active server: <strong>{activeServer.label}</strong> · {activeServer.baseUrl}
        </div>

        <div className="metric-row">
          <span className="server-chip">FHIR R4</span>
          <span className="metric-pill">Loaded patients: {patients.length}</span>
          <span className="metric-pill">Visible patients: {visiblePatients.length}</span>
        </div>

        <div className="field-group patient-search-group">
          <label htmlFor="patient-search">Search patients</label>
          <input
            id="patient-search"
            type="text"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by name, DOB, gender, or MRN"
          />
        </div>

        <div className="page-actions">
          <button
            type="button"
            className="secondary-button outline"
            onClick={() => navigateTo('/')}
          >
            Back to server selection
          </button>
        </div>

        {isLoading ? <div className="info-banner">Loading patients...</div> : null}

        {errorMessage ? <div className="error-banner">{errorMessage}</div> : null}

        {!isLoading && !errorMessage ? (
          visiblePatients.length > 0 ? (
            <ul className="patient-list full-width-patient-list">
              {visiblePatients.map((patient) => (
                <li key={patient.id} className="patient-list-item">
                  <div>
                    <p className="patient-name">{patient.name}</p>
                    <p className="patient-meta">
                      {patient.gender} · DOB {patient.dob}
                    </p>
                    <p className="patient-meta">MRN {patient.mrn}</p>
                  </div>
                  <button
                    type="button"
                    className="secondary-button compact"
                    onClick={() => navigateTo(`/patients/${patient.id}`)}
                  >
                    View
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
