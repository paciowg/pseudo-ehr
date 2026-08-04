import { useMemo, useState } from 'react'
import { validateFhirServer } from '../../lib/fhir/client'
import { navigateTo } from '../../lib/routing/routes'
import { useSavedServers } from './useSavedServers'

const INITIAL_LABEL = 'Local HAPI Demo'
const INITIAL_URL = 'http://localhost:8080/fhir'

export function ServerConnectPage() {
  const { savedServers, activeServer, connectServer, activateServer, deleteServer } =
    useSavedServers()

  const [label, setLabel] = useState(INITIAL_LABEL)
  const [baseUrl, setBaseUrl] = useState(INITIAL_URL)
  const [isConnecting, setIsConnecting] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [successMessage, setSuccessMessage] = useState('')

  const hasSavedServers = useMemo(() => savedServers.length > 0, [savedServers])

  async function handleConnect(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setErrorMessage('')
    setSuccessMessage('')
    setIsConnecting(true)

    try {
      await validateFhirServer(baseUrl)
      const server = connectServer({ label, baseUrl })
      setSuccessMessage(`Connected to ${server.label}.`)
      navigateTo('/patients')
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Unable to connect to the FHIR server.',
      )
    } finally {
      setIsConnecting(false)
    }
  }

  function handleUseSavedServer(baseUrlToUse: string) {
    const server = savedServers.find((item) => item.baseUrl === baseUrlToUse)
    if (!server) return

    activateServer(server)
    setSuccessMessage(`Using ${server.label}.`)
    setErrorMessage('')
    navigateTo('/patients')
  }

  return (
    <>
      <section className="panel">
        <div className="panel-header">
          <div>
            <p className="section-kicker">Step 1</p>
            <h2>Connect to a FHIR server</h2>
          </div>
          <span className="panel-tag">Route: #/</span>
        </div>

        <div className="server-layout">
          <form className="server-form" onSubmit={handleConnect}>
            {activeServer ? (
              <div className="active-server-banner">
                Active server: <strong>{activeServer.label}</strong> ·{' '}
                {activeServer.baseUrl}
              </div>
            ) : null}

            {successMessage ? (
              <div className="success-banner">{successMessage}</div>
            ) : null}

            {errorMessage ? <div className="error-banner">{errorMessage}</div> : null}

            <div className="field-group">
              <label htmlFor="server-label">Server label</label>
              <input
                id="server-label"
                type="text"
                value={label}
                onChange={(event) => setLabel(event.target.value)}
                placeholder="Local HAPI Demo"
              />
            </div>

            <div className="field-group">
              <label htmlFor="server-url">FHIR base URL</label>
              <input
                id="server-url"
                type="url"
                value={baseUrl}
                onChange={(event) => setBaseUrl(event.target.value)}
                placeholder="https://example.com/fhir"
              />
            </div>

            <div className="form-actions">
              <button type="submit" className="primary-button" disabled={isConnecting}>
                {isConnecting ? 'Connecting...' : 'Connect'}
              </button>

              <button
                type="button"
                className="secondary-button outline"
                onClick={() => {
                  setLabel(INITIAL_LABEL)
                  setBaseUrl(INITIAL_URL)
                  setErrorMessage('')
                  setSuccessMessage('')
                }}
                disabled={isConnecting}
              >
                Reset
              </button>
            </div>

            <p className="helper-text">
              Phase 1 targets FHIR R4 demo servers. Connection validation checks
              the server metadata endpoint before saving the server locally.
            </p>
          </form>

          <div className="saved-server-panel">
            <h3>Previously Connected Servers</h3>

            {hasSavedServers ? (
              <ul className="saved-server-list">
                {savedServers.map((server) => {
                  const isActive = activeServer?.baseUrl === server.baseUrl

                  return (
                    <li
                      key={server.id}
                      className={isActive ? 'saved-server-item active' : 'saved-server-item'}
                    >
                      <div>
                        <p className="saved-server-name">{server.label}</p>
                        <p className="saved-server-url">{server.baseUrl}</p>
                      </div>
                      <div className="saved-server-meta">
                        <span>
                          Last used {new Date(server.lastUsedAt).toLocaleString()}
                        </span>
                        <div className="saved-server-actions">
                          <button
                            type="button"
                            className="link-button"
                            onClick={() => handleUseSavedServer(server.baseUrl)}
                          >
                            Use
                          </button>
                          <button
                            type="button"
                            className="link-button link-button-danger"
                            onClick={() => deleteServer(server.baseUrl)}
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    </li>
                  )
                })}
              </ul>
            ) : (
              <p className="empty-state">No saved servers yet.</p>
            )}
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
              <li>FHIR R4 demo endpoints</li>
              <li>Local saved-server persistence</li>
              <li>Hash-based routing for static hosting</li>
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
            <h3>Data behavior</h3>
            <ul>
              <li>Connect by validating CapabilityStatement metadata</li>
              <li>Load up to 100 Patient resources</li>
              <li>Filter patients client-side</li>
              <li>Use Patient/$everything with Patient fallback</li>
            </ul>
          </article>
        </div>
      </section>
    </>
  )
}
