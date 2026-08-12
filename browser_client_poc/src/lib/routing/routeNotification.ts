const ROUTE_NOTIFICATION_KEY = 'pacio.browserClient.routeNotification'

export type RouteNotificationTone = 'success' | 'warning' | 'error' | 'info'

export type RouteNotification = {
  routeHref: string
  message: string
  tone: RouteNotificationTone
}

function isBrowser() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined'
}

export function setRouteNotification(notification: RouteNotification) {
  if (!isBrowser()) return
  window.localStorage.setItem(ROUTE_NOTIFICATION_KEY, JSON.stringify(notification))
}

export function getRouteNotification(): RouteNotification | null {
  if (!isBrowser()) return null

  const raw = window.localStorage.getItem(ROUTE_NOTIFICATION_KEY)
  if (!raw) return null

  try {
    const parsed = JSON.parse(raw) as RouteNotification

    if (!parsed?.routeHref || !parsed?.message || !parsed?.tone) {
      return null
    }

    return parsed
  } catch {
    return null
  }
}

export function clearRouteNotification() {
  if (!isBrowser()) return
  window.localStorage.removeItem(ROUTE_NOTIFICATION_KEY)
}
