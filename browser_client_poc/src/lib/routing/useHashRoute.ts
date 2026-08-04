import { useEffect, useState } from 'react'
import { parseHashRoute, type AppRoute } from './routes'

function getCurrentRoute(): AppRoute {
  return parseHashRoute(window.location.hash)
}

export function useHashRoute() {
  const [route, setRoute] = useState<AppRoute>(() => getCurrentRoute())

  useEffect(() => {
    function handleHashChange() {
      setRoute(getCurrentRoute())
    }

    window.addEventListener('hashchange', handleHashChange)

    if (!window.location.hash) {
      window.location.hash = '/'
    } else {
      handleHashChange()
    }

    return () => {
      window.removeEventListener('hashchange', handleHashChange)
    }
  }, [])

  return route
}
