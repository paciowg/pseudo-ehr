import type { Bundle, HumanName, Identifier, Patient } from 'fhir/r4'
import { getDisplayNameFromHumanName, getFirstMrn, placeholderValue } from '../../lib/fhir/formatters'

export type PatientListItem = {
  id: string
  name: string
  dob: string
  gender: string
  mrn: string
}

export function buildPatientListItems(bundle: Bundle): PatientListItem[] {
  const entries = bundle.entry ?? []

  return entries
    .map((entry) => entry.resource)
    .filter((resource): resource is Patient => resource?.resourceType === 'Patient')
    .map((patient) => ({
      id: patient.id ?? '',
      name: getPatientName(patient.name),
      dob: patient.birthDate || placeholderValue(),
      gender: patient.gender ? capitalize(patient.gender) : placeholderValue(),
      mrn: getFirstMrn(patient.identifier) || placeholderValue(),
    }))
    .filter((patient) => Boolean(patient.id))
    .sort((a, b) => a.name.localeCompare(b.name))
}

function getPatientName(names: HumanName[] | undefined) {
  if (!names || names.length === 0) return placeholderValue()
  return getDisplayNameFromHumanName(names[0]) || placeholderValue()
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

export function filterPatients(items: PatientListItem[], query: string) {
  const normalizedQuery = query.trim().toLowerCase()
  if (!normalizedQuery) return items

  return items.filter((patient) => {
    const haystack = [patient.name, patient.dob, patient.gender, patient.mrn]
      .join(' ')
      .toLowerCase()

    return haystack.includes(normalizedQuery)
  })
}

export function getFirstPatientMrn(identifiers: Identifier[] | undefined) {
  return getFirstMrn(identifiers) || placeholderValue()
}
