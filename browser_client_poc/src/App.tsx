import './App.css'

type PreviouslyConnectedServer = {
  id: string
  label: string
  baseUrl: string
  lastUsed: string
}

type PatientListItem = {
  id: string
  name: string
  dob: string
  gender: string
  mrn: string
}

type EmergencyContact = {
  name: string
  relationship: string
  phone: string
  email: string
  address: string
}

type ClinicalListItem = {
  title: string
  dateLabel?: string
  dateValue?: string
  secondaryText?: string
}

const previouslyConnectedServers: PreviouslyConnectedServer[] = [
  {
    id: 'demo-hapi',
    label: 'Local HAPI Demo',
    baseUrl: 'http://localhost:8080/fhir',
    lastUsed: 'Last used today',
  },
  {
    id: 'public-sandbox',
    label: 'Public Sandbox',
    baseUrl: 'https://example.fhir.server/r4',
    lastUsed: 'Last used 2 days ago',
  },
]

const patients: PatientListItem[] = [
  {
    id: 'patient-betsysmith-johnson01',
    name: 'Betsy Smith-Johnson',
    dob: '1950-11-15',
    gender: 'Female',
    mrn: '1032702',
  },
  {
    id: 'patient-charles-johnson',
    name: 'Charles Johnson',
    dob: '1975-06-24',
    gender: 'Male',
    mrn: '2048391',
  },
  {
    id: 'patient-lisa-johnson',
    name: 'Lisa Johnson',
    dob: '1978-02-03',
    gender: 'Female',
    mrn: '2048392',
  },
]

const emergencyContacts: EmergencyContact[] = [
  {
    name: 'Charles Johnson',
    relationship: 'Son',
    phone: '(555) 555-2222',
    email: '--',
    address: '17040 E Warren Avenue, Detroit, MI 48224',
  },
  {
    name: 'Lisa Johnson',
    relationship: 'Daughter-in-law',
    phone: '(555) 555-3333',
    email: '--',
    address: '17040 E Warren Avenue, Detroit, MI 48224',
  },
]

const activeProblems: ClinicalListItem[] = [
  {
    title: 'Essential hypertension',
    dateLabel: 'Onset',
    dateValue: '2018-03-14',
  },
  {
    title: 'Type 2 diabetes mellitus',
    dateLabel: 'Recorded',
    dateValue: '2019-07-22',
  },
  {
    title: 'Osteoarthritis of knee',
    dateLabel: 'Onset',
    dateValue: '2021-01-09',
  },
  {
    title: 'Hyperlipidemia',
    dateLabel: 'Recorded',
    dateValue: '2017-11-05',
  },
]

const currentMedications: ClinicalListItem[] = [
  {
    title: 'Lisinopril 10 MG Oral Tablet',
    dateLabel: 'Authored',
    dateValue: '2024-02-11',
  },
  {
    title: 'Metformin 500 MG Oral Tablet',
    dateLabel: 'Authored',
    dateValue: '2024-01-28',
  },
  {
    title: 'Atorvastatin 20 MG Oral Tablet',
    dateLabel: 'Authored',
    dateValue: '2024-03-02',
  },
]

const knownAllergies: ClinicalListItem[] = [
  {
    title: 'Penicillin',
    dateLabel: 'Recorded',
    dateValue: '2016-06-18',
    secondaryText: 'Medication allergy',
  },
  {
    title: 'Shellfish',
    dateLabel: 'Recorded',
    dateValue: '2014-09-03',
    secondaryText: 'Food allergy',
  },
]

const mostRecentVitals: ClinicalListItem[] = [
  {
    title: 'Blood pressure',
    secondaryText: '132/78 mmHg',
    dateLabel: 'Observed',
    dateValue: '2025-01-12',
  },
  {
    title: 'Heart rate',
    secondaryText: '72 bpm',
    dateLabel: 'Observed',
    dateValue: '2025-01-12',
  },
  {
    title: 'Respiratory rate',
    secondaryText: '16 breaths/min',
    dateLabel: 'Observed',
    dateValue: '2025-01-12',
  },
  {
    title: 'Body temperature',
    secondaryText: '98.4 °F',
    dateLabel: 'Observed',
    dateValue: '2025-01-12',
  },
  {
    title: 'Oxygen saturation',
    secondaryText: '98%',
    dateLabel: 'Observed',
    dateValue: '2025-01-12',
  },
]

function ClinicalSummarySection({
  title,
  items,
  emptyMessage = 'None recorded',
}: {
  title: string
  items: ClinicalListItem[]
  emptyMessage?: string
}) {
  const visibleItems = items.slice(0, 10)

  return (
    <section className="summary-card clinical-summary-card">
      <div className="clinical-summary-header">
        <h3>{title}</h3>
        <span className="clinical-summary-cap">Up to 10 items</span>
      </div>

      {visibleItems.length > 0 ? (
        <ul className="clinical-list">
          {visibleItems.map((item) => (
            <li
              key={`${title}-${item.title}-${item.dateValue ?? ''}-${item.secondaryText ?? ''}`}
              className="clinical-list-item"
            >
              <div className="clinical-list-main">
                <p className="clinical-item-title">{item.title}</p>
                {item.secondaryText ? (
                  <p className="clinical-item-secondary">{item.secondaryText}</p>
                ) : null}
              </div>

              <div className="clinical-item-meta">
                {item.dateLabel && item.dateValue ? (
                  <>
                    <span className="clinical-item-date-label">
                      {item.dateLabel}
                    </span>
                    <span className="clinical-item-date-value">
                      {item.dateValue}
                    </span>
                  </>
                ) : (
                  <span className="clinical-item-date-value">--</span>
                )}
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <p className="empty-state">{emptyMessage}</p>
      )}
    </section>
  )
}

function App() {
  return (
    <div className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow">PACIO Browser Client POC</p>
          <h1>Phase 1 first pass</h1>
          <p className="subtitle">
            A read-only browser client exploring a simpler reference
            implementation for connecting to a FHIR server, browsing patients,
            and rendering a Rails-inspired patient summary.
          </p>
        </div>

        <div className="header-status-card">
          <span className="status-pill">Read-only</span>
          <span className="status-pill">Open FHIR endpoints</span>
          <span className="status-pill">No backend</span>
        </div>
      </header>

      <main className="app-main">
        <section className="panel">
          <div className="panel-header">
            <div>
              <p className="section-kicker">Step 1</p>
              <h2>Connect to a FHIR server</h2>
            </div>
            <span className="panel-tag">Planned route: /</span>
          </div>

          <div className="server-layout">
            <form className="server-form">
              <div className="field-group">
                <label htmlFor="server-label">Server label</label>
                <input
                  id="server-label"
                  type="text"
                  value="Local HAPI Demo"
                  readOnly
                />
              </div>

              <div className="field-group">
                <label htmlFor="server-url">FHIR base URL</label>
                <input
                  id="server-url"
                  type="text"
                  value="http://localhost:8080/fhir"
                  readOnly
                />
              </div>

              <div className="form-actions">
                <button type="button" className="primary-button">
                  Connect
                </button>
              </div>

              <p className="helper-text">
                Phase 1 assumes open endpoints only. Connected servers should be
                added automatically to the previously connected list and shown
                with the most recently used first.
              </p>
            </form>

            <div className="saved-server-panel">
              <h3>Previously Connected Servers</h3>
              <ul className="saved-server-list">
                {previouslyConnectedServers.map((server) => (
                  <li key={server.id} className="saved-server-item">
                    <div>
                      <p className="saved-server-name">{server.label}</p>
                      <p className="saved-server-url">{server.baseUrl}</p>
                    </div>
                    <div className="saved-server-meta">
                      <span>{server.lastUsed}</span>
                      <div className="saved-server-actions">
                        <button type="button" className="link-button">
                          Use
                        </button>
                        <button
                          type="button"
                          className="link-button link-button-danger"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        <section className="panel">
          <div className="panel-header">
            <div>
              <p className="section-kicker">Step 2</p>
              <h2>Browse patients</h2>
            </div>
            <span className="panel-tag">Planned route: /patients</span>
          </div>

          <div className="patient-list-panel full-width-panel">
            <div className="active-server-banner">
              Active server: <strong>Local HAPI Demo</strong>
            </div>

            <div className="field-group patient-search-group">
              <label htmlFor="patient-search">Search patients</label>
              <input
                id="patient-search"
                type="text"
                value="betsy"
                readOnly
              />
            </div>

            <ul className="patient-list full-width-patient-list">
              {patients.map((patient) => (
                <li
                  key={patient.id}
                  className={
                    patient.id === 'patient-betsysmith-johnson01'
                      ? 'patient-list-item selected'
                      : 'patient-list-item'
                  }
                >
                  <div>
                    <p className="patient-name">{patient.name}</p>
                    <p className="patient-meta">
                      {patient.gender} · DOB {patient.dob}
                    </p>
                    <p className="patient-meta">MRN {patient.mrn}</p>
                  </div>
                  <button type="button" className="secondary-button compact">
                    View
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className="panel">
          <div className="panel-header">
            <div>
              <p className="section-kicker">Step 3</p>
              <h2>Patient summary</h2>
            </div>
            <span className="panel-tag">Planned route: /patients/:id</span>
          </div>

          <div className="summary-preview-panel full-width-panel">
            <section className="patient-summary-hero">
              <div>
                <p className="patient-summary-name">Betsy Smith-Johnson</p>
                <p className="patient-summary-meta">
                  Female, 75 years · DOB: 1950-11-15 · MRN: 1032702
                </p>
              </div>
              <div className="bundle-status success">
                $everything data available
              </div>
            </section>

            <div className="summary-grid">
              <section className="summary-card wide">
                <h3>Personal Information</h3>
                <dl className="detail-grid">
                  <div>
                    <dt>First name</dt>
                    <dd>Betsy</dd>
                  </div>
                  <div>
                    <dt>Last name</dt>
                    <dd>Smith-Johnson</dd>
                  </div>
                  <div>
                    <dt>Date of birth</dt>
                    <dd>1950-11-15</dd>
                  </div>
                  <div>
                    <dt>Gender identity</dt>
                    <dd>Female</dd>
                  </div>
                  <div>
                    <dt>Sex assigned at birth</dt>
                    <dd>--</dd>
                  </div>
                  <div>
                    <dt>Marital status</dt>
                    <dd>Unknown</dd>
                  </div>
                  <div className="span-2">
                    <dt>Medical record number</dt>
                    <dd>1032702</dd>
                  </div>
                </dl>
              </section>

              <section className="summary-card">
                <h3>Demographics</h3>
                <dl className="stacked-details">
                  <div>
                    <dt>Race</dt>
                    <dd>White</dd>
                  </div>
                  <div>
                    <dt>Ethnicity</dt>
                    <dd>--</dd>
                  </div>
                  <div>
                    <dt>Language</dt>
                    <dd>EN</dd>
                  </div>
                </dl>
              </section>

              <section className="summary-card">
                <h3>Contact Information</h3>
                <dl className="stacked-details">
                  <div>
                    <dt>Address</dt>
                    <dd>17040 E Warren Avenue, Detroit, MI, 48224, US</dd>
                  </div>
                  <div>
                    <dt>Phone</dt>
                    <dd>555-555-1111</dd>
                  </div>
                  <div>
                    <dt>Email</dt>
                    <dd>mmoen+betsysmithjohnson@mydirectives.com</dd>
                  </div>
                </dl>
              </section>

              <section className="summary-card wide">
                <h3>Emergency Contacts</h3>
                <div className="contact-cards">
                  {emergencyContacts.map((contact) => (
                    <article key={contact.name} className="contact-card">
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
              </section>

              <ClinicalSummarySection
                title="Active Problems"
                items={activeProblems}
              />
              <ClinicalSummarySection
                title="Current Medications"
                items={currentMedications}
              />
              <ClinicalSummarySection
                title="Known Allergies"
                items={knownAllergies}
              />
              <ClinicalSummarySection
                title="Most Recent Vitals"
                items={mostRecentVitals}
              />
            </div>
          </div>
        </section>

        <section className="panel">
          <div className="panel-header">
            <div>
              <p className="section-kicker">Implementation Notes</p>
              <h2>What this first pass establishes</h2>
            </div>
          </div>

          <div className="notes-grid">
            <article className="note-card">
              <h3>Agreed scope</h3>
              <ul>
                <li>Read-only Phase 1</li>
                <li>Open FHIR endpoints only</li>
                <li>FHIR server selection and previously connected servers</li>
                <li>Patient list and patient summary flow</li>
              </ul>
            </article>

            <article className="note-card">
              <h3>Patient summary shape</h3>
              <ul>
                <li>Personal information</li>
                <li>Demographics</li>
                <li>Contact information</li>
                <li>Emergency contacts</li>
                <li>Clinical summary sections</li>
              </ul>
            </article>

            <article className="note-card">
              <h3>Planned data behavior</h3>
              <ul>
                <li>Primary patient load via Patient/$everything</li>
                <li>Patient-only fallback if bundle fetch fails</li>
                <li>Clinical sections use Conditions, MedicationRequest, AllergyIntolerance, and Observation data</li>
                <li>FHIR field extraction guided by the Rails patient model</li>
              </ul>
            </article>
          </div>
        </section>
      </main>
    </div>
  )
}

export default App
