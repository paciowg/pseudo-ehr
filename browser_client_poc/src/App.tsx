import { useEffect, useState } from 'react'
import './App.css'
import { useHashRoute } from './lib/routing/useHashRoute'
import { getRouteHref, navigateTo } from './lib/routing/routes'
import { AppLayout } from './components/AppLayout'
import { ServerConnectPage } from './features/servers/ServerConnectPage'
import { PatientListPage } from './features/patients/PatientListPage'
import { PatientSummaryPage } from './features/patientSummary/PatientSummaryPage'
import { PatientPmoCreatePage } from './features/patientSummary/PatientPmoCreatePage'
import { useSavedServers } from './features/servers/useSavedServers'
import {
  clearRouteNotification,
  getRouteNotification,
  type RouteNotification,
} from './lib/routing/routeNotification'

function App() {
  const route = useHashRoute()
  const { activeServer } = useSavedServers()
  const [notification, setNotification] = useState<RouteNotification | null>(() =>
    getRouteNotification(),
  )

  useEffect(() => {
    setNotification(getRouteNotification())
  }, [route])

  useEffect(() => {
    if (activeServer && route.name === 'home') {
      navigateTo('/patients')
      return
    }

    if (!activeServer && route.name !== 'home') {
      navigateTo('/')
    }
  }, [activeServer, route])

  useEffect(() => {
    if (!notification) return

    const currentHref = getRouteHref(window.location.hash.replace(/^#/, '') || '/')
    if (currentHref !== notification.routeHref) {
      clearRouteNotification()
      setNotification(null)
    }
  }, [notification, route])

  return (
    <AppLayout notification={notification}>
      {route.name === 'home' ? <ServerConnectPage /> : null}
      {route.name === 'patients' ? <PatientListPage /> : null}
      {route.name === 'patientDetail' ? (
        <PatientSummaryPage patientId={route.patientId} />
      ) : null}
      {route.name === 'patientPmoCreate' ? (
        <PatientPmoCreatePage patientId={route.patientId} />
      ) : null}
    </AppLayout>
  )
}

export default App
