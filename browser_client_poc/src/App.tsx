import './App.css'
import { useHashRoute } from './lib/routing/useHashRoute'
import { AppLayout } from './components/AppLayout'
import { ServerConnectPage } from './features/servers/ServerConnectPage'
import { PatientListPage } from './features/patients/PatientListPage'
import { PatientSummaryPage } from './features/patientSummary/PatientSummaryPage'

function App() {
  const route = useHashRoute()

  return (
    <AppLayout>
      {route.name === 'home' ? <ServerConnectPage /> : null}
      {route.name === 'patients' ? <PatientListPage /> : null}
      {route.name === 'patientDetail' ? (
        <PatientSummaryPage patientId={route.patientId} />
      ) : null}
    </AppLayout>
  )
}

export default App
