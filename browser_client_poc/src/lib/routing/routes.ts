export type AppRoute =
  | { name: 'home' }
  | { name: 'patients' }
  | { name: 'patientDetail'; patientId: string }
  | { name: 'patientPmoCreate'; patientId: string }
  | { name: 'advanceDirectiveDetail'; patientId: string; documentReferenceId: string }

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

  if (
    segments.length === 4 &&
    segments[0] === 'patients' &&
    segments[2] === 'advance-directives'
  ) {
    return {
      name: 'advanceDirectiveDetail',
      patientId: decodeURIComponent(segments[1]),
      documentReferenceId: decodeURIComponent(segments[3]),
    }
  }

  if (
    segments.length === 3 &&
    segments[0] === 'patients' &&
    segments[2] === 'pmo'
  ) {
    return { name: 'patientPmoCreate', patientId: decodeURIComponent(segments[1]) }
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
