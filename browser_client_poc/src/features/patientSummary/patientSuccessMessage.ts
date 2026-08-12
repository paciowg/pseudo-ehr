const PATIENT_SUCCESS_MESSAGE_KEY = 'pacio.browserClient.patientSuccessMessage'

type PatientSuccessMessage = {
  patientId: string
  message: string
}

function isBrowser() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined'
}

export function setPatientSuccessMessage(message: PatientSuccessMessage) {
  if (!isBrowser()) return
  window.localStorage.setItem(PATIENT_SUCCESS_MESSAGE_KEY, JSON.stringify(message))
}

export function consumePatientSuccessMessage(patientId: string) {
  if (!isBrowser()) return ''

  const raw = window.localStorage.getItem(PATIENT_SUCCESS_MESSAGE_KEY)
  if (!raw) return ''

  window.localStorage.removeItem(PATIENT_SUCCESS_MESSAGE_KEY)

  try {
    const parsed = JSON.parse(raw) as PatientSuccessMessage
    return parsed.patientId === patientId ? parsed.message : ''
  } catch {
    return ''
  }
}
