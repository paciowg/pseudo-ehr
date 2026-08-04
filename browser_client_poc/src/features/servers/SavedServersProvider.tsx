import type { ReactNode } from 'react'
import { useCallback, useMemo, useState } from 'react'
import {
  clearActiveServer,
  getActiveServer,
  getSavedServers,
  removeSavedServer,
  saveServer,
  setActiveServer,
  type SavedServer,
} from './serverStorage'
import { SavedServersContext, type SavedServersContextValue } from './useSavedServers'

type SavedServersProviderProps = {
  children: ReactNode
}

export function SavedServersProvider({ children }: SavedServersProviderProps) {
  const [savedServers, setSavedServers] = useState<SavedServer[]>(() => getSavedServers())
  const [activeServer, setActiveServerState] = useState<SavedServer | null>(() =>
    getActiveServer(),
  )

  const refresh = useCallback(() => {
    setSavedServers(getSavedServers())
    setActiveServerState(getActiveServer())
  }, [])

  const connectServer = useCallback(
    (input: { label: string; baseUrl: string }) => {
      const server = saveServer(input)
      refresh()
      return server
    },
    [refresh],
  )

  const activateServer = useCallback(
    (server: SavedServer) => {
      const nextServer = setActiveServer(server)
      refresh()
      return nextServer
    },
    [refresh],
  )

  const disconnectServer = useCallback(() => {
    clearActiveServer()
    refresh()
  }, [refresh])

  const deleteServer = useCallback(
    (baseUrl: string) => {
      removeSavedServer(baseUrl)
      refresh()
    },
    [refresh],
  )

  const value = useMemo<SavedServersContextValue>(
    () => ({
      savedServers,
      activeServer,
      connectServer,
      activateServer,
      disconnectServer,
      deleteServer,
      refresh,
    }),
    [
      savedServers,
      activeServer,
      connectServer,
      activateServer,
      disconnectServer,
      deleteServer,
      refresh,
    ],
  )

  return (
    <SavedServersContext.Provider value={value}>
      {children}
    </SavedServersContext.Provider>
  )
}
