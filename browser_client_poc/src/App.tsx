import { useEffect } from 'react'
import './App.css'
import { useHashRoute } from './lib/routing/useHashRoute'
import { navigateTo } from './lib/routing/routes'
import { AppLayout } from './components/AppLayout'
import { ServerConnectPage } from './features/servers/ServerConnectPage'
import { PatientListPage } from './features/patients/PatientListPage'
import { PatientSummaryPage } from './features/patientSummary/PatientSummaryPage'
import { useSavedServers } from './features/servers/useSavedServers'

function App() {
  const route = useHashRoute()
  const { activeServer } = useSavedServers()

  useEffect(() => {
    if (activeServer && route.name === 'home') {
      navigateTo('/patients')
      return
    }

    if (!activeServer && route.name !== 'home') {
      navigateTo('/')
    }
  }, [activeServer, route])

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
