import type { ReactNode } from 'react'
import { getRouteHref } from '../lib/routing/routes'

type AppLayoutProps = {
  children: ReactNode
}

export function AppLayout({ children }: AppLayoutProps) {
  return (
    <div className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow">PACIO Browser Client POC</p>
          <h1>Phase 1 browser client</h1>
          <p className="subtitle">
            A read-only browser client for connecting directly to FHIR R4 demo
            servers, browsing patients, and rendering a browser-based patient
            summary without a backend application server.
          </p>
        </div>

        <div className="header-status-card">
          <a className="status-pill" href={getRouteHref('/')}>
            Server connect
          </a>
          <a className="status-pill" href={getRouteHref('/patients')}>
            Patients
          </a>
          <span className="status-pill">FHIR R4</span>
          <span className="status-pill">Read-only</span>
          <span className="status-pill">No backend</span>
        </div>
      </header>

      <main className="app-main">{children}</main>
    </div>
  )
}
