export type AppRoute =
  | { name: 'home' }
  | { name: 'patients' }
  | { name: 'patientDetail'; patientId: string }

export function parseHashRoute(hash: string): AppRoute {
  const raw = hash.replace(/^#/, '') || '/'
  const [pathname] = raw.split('?')
  const normalizedPath = pathname.startsWith('/') ? pathname : `/${pathname}`
  const segments = normalizedPath.split('/').filter(Boolean)

  if (segments.length === 0) {
    return { name: 'home' }
  }

  if (segments.length === 1 && segments[0] === 'patients') {
    return { name: 'patients' }
  }

  if (segments.length === 2 && segments[0] === 'patients') {
    return { name: 'patientDetail', patientId: decodeURIComponent(segments[1]) }
  }

  return { name: 'home' }
}

export function getRouteHref(path: string) {
  return `#${path}`
}

export function navigateTo(path: string) {
  window.location.hash = path
}
