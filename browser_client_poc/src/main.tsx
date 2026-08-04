import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { SavedServersProvider } from './features/servers/SavedServersProvider.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <SavedServersProvider>
      <App />
    </SavedServersProvider>
  </StrictMode>,
)
