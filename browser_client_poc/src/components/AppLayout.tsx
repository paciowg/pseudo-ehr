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
          <h1>PACIO Explorer Reference Client</h1>
        </div>

        <div className="header-status-card">
          <a className="status-pill" href={getRouteHref('/')}>
            Server connect
          </a>
          <a className="status-pill" href={getRouteHref('/patients')}>
            Patients
          </a>
          <span className="status-pill">FHIR R4</span>
        </div>
      </header>

      <main className="app-main">{children}</main>
    </div>
  )
}
