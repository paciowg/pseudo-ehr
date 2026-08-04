import { createContext, useContext } from 'react'
import type { SavedServer } from './serverStorage'

export type SavedServersContextValue = {
  savedServers: SavedServer[]
  activeServer: SavedServer | null
  connectServer: (input: { label: string; baseUrl: string }) => SavedServer
  activateServer: (server: SavedServer) => SavedServer
  disconnectServer: () => void
  deleteServer: (baseUrl: string) => void
  refresh: () => void
}

export const SavedServersContext = createContext<SavedServersContextValue | null>(null)

export function useSavedServers() {
  const context = useContext(SavedServersContext)

  if (!context) {
    throw new Error('useSavedServers must be used within a SavedServersProvider.')
  }

  return context
}
