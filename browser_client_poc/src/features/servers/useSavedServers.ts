import { useCallback, useMemo, useState } from 'react'
import {
  getActiveServer,
  getSavedServers,
  removeSavedServer,
  saveServer,
  setActiveServer,
  type SavedServer,
} from './serverStorage'

export function useSavedServers() {
  const [savedServers, setSavedServers] = useState<SavedServer[]>(() => getSavedServers())
  const [activeServer, setActiveServerState] = useState<SavedServer | null>(() => getActiveServer())

  const refresh = useCallback(() => {
    setSavedServers(getSavedServers())
    setActiveServerState(getActiveServer())
  }, [])

  const connectServer = useCallback((input: { label: string; baseUrl: string }) => {
    const server = saveServer(input)
    refresh()
    return server
  }, [refresh])

  const activateServer = useCallback((server: SavedServer) => {
    const nextServer = setActiveServer(server)
    refresh()
    return nextServer
  }, [refresh])

  const deleteServer = useCallback((baseUrl: string) => {
    removeSavedServer(baseUrl)
    refresh()
  }, [refresh])

  return useMemo(
    () => ({
      savedServers,
      activeServer,
      connectServer,
      activateServer,
      deleteServer,
      refresh,
    }),
    [savedServers, activeServer, connectServer, activateServer, deleteServer, refresh],
  )
}
