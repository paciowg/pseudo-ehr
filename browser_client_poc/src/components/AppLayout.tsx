import type { ReactNode } from 'react'
import { getRouteHref, navigateTo } from '../lib/routing/routes'
import { useSavedServers } from '../features/servers/useSavedServers'

type AppLayoutProps = {
  children: ReactNode
}

export function AppLayout({ children }: AppLayoutProps) {
  const { activeServer, disconnectServer } = useSavedServers()

  function handleDisconnect() {
    disconnectServer()
    navigateTo('/')
  }

  return (
    <div className="app-shell">
      <header className="app-header">
        <div>
          <h1>PACIO Explorer Reference Client</h1>
        </div>

        {activeServer ? (
          <div className="header-status-card">
            <a className="status-pill" href={getRouteHref('/patients')}>
              Patients
            </a>
            <button type="button" className="status-pill status-pill-button" onClick={handleDisconnect}>
              Disconnect
            </button>
          </div>
        ) : null}
      </header>

      <main className="app-main">{children}</main>
    </div>
  )
}
