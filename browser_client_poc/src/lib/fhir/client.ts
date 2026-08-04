import type { Bundle, CapabilityStatement, Patient } from 'fhir/r4'
import { normalizeBaseUrl } from '../../features/servers/serverStorage'

type FhirJson = Bundle | CapabilityStatement | Patient

async function fhirGet<T extends FhirJson>(baseUrl: string, path: string): Promise<T> {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl)
  const response = await fetch(`${normalizedBaseUrl}${path}`, {
    headers: {
      Accept: 'application/fhir+json, application/json',
    },
  })

  const contentType = response.headers.get('content-type') || ''
  const hasJsonBody = contentType.includes('json')
  const payload = hasJsonBody ? await response.json() : null

  if (!response.ok) {
    const operationOutcomeIssue = payload?.issue?.[0]
    const issueText =
      operationOutcomeIssue?.diagnostics ||
      operationOutcomeIssue?.details?.text ||
      operationOutcomeIssue?.code

    throw new Error(issueText || `FHIR request failed with status ${response.status}.`)
  }

  return payload as T
}

export async function validateFhirServer(baseUrl: string) {
  const capabilityStatement = await fhirGet<CapabilityStatement>(baseUrl, '/metadata')

  if (capabilityStatement.resourceType !== 'CapabilityStatement') {
    throw new Error('The server metadata endpoint did not return a CapabilityStatement.')
  }

  const fhirVersion = capabilityStatement.fhirVersion || ''
  if (!fhirVersion.startsWith('4.')) {
    throw new Error(`Unsupported FHIR version: ${fhirVersion || 'unknown'}. Phase 1 targets FHIR R4.`)
  }

  return capabilityStatement
}

export async function fetchPatients(baseUrl: string, count = 100) {
  return fhirGet<Bundle>(baseUrl, `/Patient?_count=${count}`)
}

export async function fetchPatient(baseUrl: string, patientId: string) {
  const patient = await fhirGet<Patient>(baseUrl, `/Patient/${encodeURIComponent(patientId)}`)

  if (patient.resourceType !== 'Patient') {
    throw new Error('The server did not return a Patient resource.')
  }

  return patient
}

export async function fetchPatientEverything(baseUrl: string, patientId: string) {
  const bundle = await fhirGet<Bundle>(
    baseUrl,
    `/Patient/${encodeURIComponent(patientId)}/$everything`,
  )

  if (bundle.resourceType !== 'Bundle') {
    throw new Error('The server did not return a Bundle for Patient/$everything.')
  }

  return bundle
}
