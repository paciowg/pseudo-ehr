export type SavedServer = {
  id: string
  label: string
  baseUrl: string
  lastUsedAt: string
}

const SAVED_SERVERS_KEY = 'pacio.browserClient.savedServers'
const ACTIVE_SERVER_KEY = 'pacio.browserClient.activeServer'

function isBrowser() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined'
}

export function normalizeBaseUrl(baseUrl: string) {
  return baseUrl.trim().replace(/\/+$/, '')
}

function createServerId(baseUrl: string) {
  return normalizeBaseUrl(baseUrl)
}

function readJson<T>(key: string, fallback: T): T {
  if (!isBrowser()) return fallback

  const raw = window.localStorage.getItem(key)
  if (!raw) return fallback

  try {
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

function writeJson<T>(key: string, value: T) {
  if (!isBrowser()) return
  window.localStorage.setItem(key, JSON.stringify(value))
}

export function getSavedServers(): SavedServer[] {
  const saved = readJson<SavedServer[]>(SAVED_SERVERS_KEY, [])
  return saved
    .filter((server) => Boolean(server?.baseUrl))
    .map((server) => ({
      ...server,
      id: createServerId(server.baseUrl),
      baseUrl: normalizeBaseUrl(server.baseUrl),
    }))
    .sort((a, b) => (a.lastUsedAt < b.lastUsedAt ? 1 : -1))
}

export function saveServer(input: { label: string; baseUrl: string }): SavedServer {
  const baseUrl = normalizeBaseUrl(input.baseUrl)
  const label = input.label.trim() || baseUrl
  const now = new Date().toISOString()
  const nextServer: SavedServer = {
    id: createServerId(baseUrl),
    label,
    baseUrl,
    lastUsedAt: now,
  }

  const existing = getSavedServers().filter((server) => server.baseUrl !== baseUrl)
  const next = [nextServer, ...existing]
  writeJson(SAVED_SERVERS_KEY, next)
  writeJson(ACTIVE_SERVER_KEY, nextServer)
  return nextServer
}

export function removeSavedServer(baseUrl: string) {
  const normalized = normalizeBaseUrl(baseUrl)
  const next = getSavedServers().filter((server) => server.baseUrl !== normalized)
  writeJson(SAVED_SERVERS_KEY, next)

  const active = getActiveServer()
  if (active?.baseUrl === normalized && isBrowser()) {
    window.localStorage.removeItem(ACTIVE_SERVER_KEY)
  }
}

export function getActiveServer(): SavedServer | null {
  const active = readJson<SavedServer | null>(ACTIVE_SERVER_KEY, null)
  if (!active?.baseUrl) return null

  return {
    ...active,
    id: createServerId(active.baseUrl),
    baseUrl: normalizeBaseUrl(active.baseUrl),
  }
}

export function clearActiveServer() {
  if (!isBrowser()) return
  window.localStorage.removeItem(ACTIVE_SERVER_KEY)
}

export function setActiveServer(server: SavedServer) {
  const nextServer = saveServer({
    label: server.label,
    baseUrl: server.baseUrl,
  })

  writeJson(ACTIVE_SERVER_KEY, nextServer)
  return nextServer
}
