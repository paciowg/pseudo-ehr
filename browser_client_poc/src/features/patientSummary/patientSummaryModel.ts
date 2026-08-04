import type {
  Address,
  AllergyIntolerance,
  Bundle,
  CodeableConcept,
  Coding,
  Condition,
  ContactPoint,
  Extension,
  HumanName,
  MedicationStatement,
  Observation,
  Patient,
  Quantity,
  Reference,
} from 'fhir/r4'
import {
  formatAddress,
  formatDate,
  formatPhone,
  getCodeableConceptText,
  getDisplayNameFromHumanName,
  getFirstMrn,
  placeholderValue,
} from '../../lib/fhir/formatters'

export type EmergencyContact = {
  name: string
  relationship: string
  phone: string
  email: string
  address: string
}

export type ClinicalListItem = {
  title: string
  dateLabel?: string
  dateValue?: string
  secondaryText?: string
}

export type PatientSummaryModel = {
  patientId: string
  patientName: string
  patientMeta: string
  bundleStatusText: string
  bundleStatusTone: 'success' | 'warning'
  personalInformation: {
    firstName: string
    lastName: string
    birthDate: string
    gender: string
    birthSex: string
    maritalStatus: string
    mrn: string
  }
  demographics: {
    race: string
    ethnicity: string
    language: string
  }
  contactInformation: {
    address: string
    phone: string
    email: string
  }
  emergencyContacts: EmergencyContact[]
  activeProblems: ClinicalListItem[]
  currentMedications: ClinicalListItem[]
  knownAllergies: ClinicalListItem[]
  mostRecentVitals: ClinicalListItem[]
  clinicalSectionEmptyMessage: string
}

const US_CORE_RACE_URL =
  'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
const US_CORE_ETHNICITY_URL =
  'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
const US_CORE_BIRTHSEX_URL =
  'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'

const BLOOD_PRESSURE_PANEL_CODES = new Set(['85354-9'])
const SYSTOLIC_BP_CODES = new Set(['8480-6'])
const DIASTOLIC_BP_CODES = new Set(['8462-4'])
const HEART_RATE_CODES = new Set(['8867-4'])
const RESPIRATORY_RATE_CODES = new Set(['9279-1'])
const BODY_TEMPERATURE_CODES = new Set(['8310-5'])
const OXYGEN_SATURATION_CODES = new Set(['2708-6', '59408-5'])

export function buildPatientSummaryModel(input: {
  patient: Patient
  bundle: Bundle | null
  bundleAvailable: boolean
}): PatientSummaryModel {
  const { patient, bundle, bundleAvailable } = input
  const name = patient.name?.[0]
  const patientName = getDisplayNameFromHumanName(name) || placeholderValue()
  const firstName = name?.given?.[0] || placeholderValue()
  const lastName = name?.family || placeholderValue()
  const birthDate = patient.birthDate || placeholderValue()
  const gender = patient.gender ? capitalize(patient.gender) : placeholderValue()
  const mrn = getFirstMrn(patient.identifier) || placeholderValue()
  const patientMeta = [
    gender,
    `DOB: ${birthDate}`,
    `MRN: ${mrn}`,
  ].join(' · ')

  return {
    patientId: patient.id || '',
    patientName,
    patientMeta,
    bundleStatusText: bundleAvailable
      ? '$everything data available'
      : 'Showing patient-only fallback data',
    bundleStatusTone: bundleAvailable ? 'success' : 'warning',
    personalInformation: {
      firstName,
      lastName,
      birthDate,
      gender,
      birthSex: getBirthSex(patient.extension),
      maritalStatus: getMaritalStatus(patient.maritalStatus),
      mrn,
    },
    demographics: {
      race: getUsCoreCategoryDisplay(patient.extension, US_CORE_RACE_URL),
      ethnicity: getUsCoreCategoryDisplay(patient.extension, US_CORE_ETHNICITY_URL),
      language: getLanguage(patient),
    },
    contactInformation: {
      address: formatAddress(patient.address?.[0]),
      phone: formatPhone(patient.telecom),
      email: getEmail(patient.telecom),
    },
    emergencyContacts: getEmergencyContacts(patient),
    activeProblems: bundleAvailable ? getActiveProblems(bundle) : [],
    currentMedications: bundleAvailable ? getCurrentMedications(bundle) : [],
    knownAllergies: bundleAvailable ? getKnownAllergies(bundle) : [],
    mostRecentVitals: bundleAvailable ? getMostRecentVitals(bundle) : [],
    clinicalSectionEmptyMessage: bundleAvailable ? 'None recorded' : 'Unavailable',
  }
}

function getLanguage(patient: Patient) {
  const code =
    patient.communication?.[0]?.language?.coding?.[0]?.code ||
    patient.communication?.[0]?.language?.text

  return code ? code.toUpperCase() : placeholderValue()
}

function getBirthSex(extensions: Extension[] | undefined) {
  const extension = extensions?.find((item) => item.url === US_CORE_BIRTHSEX_URL)
  const value = extension?.valueCode
  return value || placeholderValue()
}

function getUsCoreCategoryDisplay(
  extensions: Extension[] | undefined,
  extensionUrl: string,
) {
  const extension = extensions?.find((item) => item.url === extensionUrl)
  const ombCategory = extension?.extension?.find((item) => item.url === 'ombCategory')
  const display =
    ombCategory?.valueCoding?.display ||
    ombCategory?.valueCoding?.code ||
    extension?.valueString

  return display || placeholderValue()
}

function getMaritalStatus(maritalStatus: CodeableConcept | undefined) {
  const code = maritalStatus?.coding?.[0]?.code

  const mapped = code
    ? {
        M: 'Married',
        S: 'Never Married',
        D: 'Divorced',
        W: 'Widowed',
        U: 'Unmarried',
        P: 'Polygamous',
      }[code]
    : undefined

  return mapped || getCodeableConceptText(maritalStatus) || placeholderValue()
}

function getEmail(telecom: ContactPoint[] | undefined) {
  const email = telecom?.find((item) => item.system === 'email')?.value
  return email || placeholderValue()
}

function getEmergencyContacts(patient: Patient): EmergencyContact[] {
  return (
    patient.contact?.map((contact, index) => ({
      name:
        contact.name?.text ||
        getDisplayNameFromHumanName(contact.name as HumanName | undefined) ||
        `Contact ${index + 1}`,
      relationship: getRelationship(contact.relationship),
      phone: formatPhone(contact.telecom),
      email: getEmail(contact.telecom),
      address: formatAddress(contact.address),
    })) ?? []
  )
}

function getRelationship(relationships: CodeableConcept[] | undefined) {
  const relationship = relationships?.[0]
  return (
    relationship?.coding?.[0]?.display ||
    relationship?.coding?.[0]?.code ||
    relationship?.text ||
    'Unknown'
  )
}

function getBundleResources<T extends { resourceType?: string }>(
  bundle: Bundle | null,
  resourceType: string,
): T[] {
  return (
    bundle?.entry
      ?.map((entry) => entry.resource)
      .filter((resource): resource is T => resource?.resourceType === resourceType) ?? []
  )
}

function getActiveProblems(bundle: Bundle | null): ClinicalListItem[] {
  return getBundleResources<Condition>(bundle, 'Condition')
    .filter((condition) => {
      const status = condition.clinicalStatus?.coding?.[0]?.code
      return !status || ['active', 'recurrence', 'relapse'].includes(status)
    })
    .map((condition) => ({
      title: getCodeableConceptText(condition.code) || placeholderValue(),
      dateLabel: condition.onsetDateTime ? 'Onset' : condition.recordedDate ? 'Recorded' : undefined,
      dateValue: condition.onsetDateTime || condition.recordedDate,
    }))
    .slice(0, 10)
}

function getCurrentMedications(bundle: Bundle | null): ClinicalListItem[] {
  return getBundleResources<MedicationStatement>(bundle, 'MedicationStatement')
    .filter((statement) => {
      const status = statement.status
      return !status || ['active', 'completed', 'intended', 'on-hold'].includes(status)
    })
    .map((statement) => ({
      title:
        getCodeableConceptText(statement.medicationCodeableConcept) ||
        statement.medicationReference?.display ||
        placeholderValue(),
      dateLabel: statement.dateAsserted || statement.effectiveDateTime || statement.effectivePeriod?.start
        ? 'Recorded'
        : undefined,
      dateValue:
        statement.dateAsserted ||
        statement.effectiveDateTime ||
        statement.effectivePeriod?.start,
    }))
    .slice(0, 10)
}

function getKnownAllergies(bundle: Bundle | null): ClinicalListItem[] {
  return getBundleResources<AllergyIntolerance>(bundle, 'AllergyIntolerance')
    .filter((allergy) => allergy.verificationStatus?.coding?.[0]?.code !== 'entered-in-error')
    .map((allergy) => ({
      title: getCodeableConceptText(allergy.code) || placeholderValue(),
      dateLabel: allergy.recordedDate ? 'Recorded' : undefined,
      dateValue: allergy.recordedDate,
      secondaryText:
        allergy.type === 'allergy'
          ? `${capitalize(allergy.category?.[0] || 'Allergy')} allergy`
          : allergy.type
            ? capitalize(allergy.type)
            : undefined,
    }))
    .slice(0, 10)
}

function getMostRecentVitals(bundle: Bundle | null): ClinicalListItem[] {
  const observations = getBundleResources<Observation>(bundle, 'Observation').filter(
    (observation) => {
      const status = observation.status
      return !status || ['final', 'amended'].includes(status)
    },
  )

  const latestBloodPressure = getLatestBloodPressure(observations)
  const latestHeartRate = getLatestQuantityObservation(observations, HEART_RATE_CODES)
  const latestRespiratoryRate = getLatestQuantityObservation(
    observations,
    RESPIRATORY_RATE_CODES,
  )
  const latestTemperature = getLatestQuantityObservation(
    observations,
    BODY_TEMPERATURE_CODES,
  )
  const latestOxygenSaturation = getLatestQuantityObservation(
    observations,
    OXYGEN_SATURATION_CODES,
  )

  return [
    latestBloodPressure,
    latestHeartRate
      ? quantityObservationToItem('Heart rate', latestHeartRate)
      : null,
    latestRespiratoryRate
      ? quantityObservationToItem('Respiratory rate', latestRespiratoryRate)
      : null,
    latestTemperature
      ? quantityObservationToItem('Body temperature', latestTemperature)
      : null,
    latestOxygenSaturation
      ? quantityObservationToItem('Oxygen saturation', latestOxygenSaturation)
      : null,
  ].filter((item): item is ClinicalListItem => Boolean(item))
}

function getLatestBloodPressure(observations: Observation[]): ClinicalListItem | null {
  const candidates = observations
    .filter((observation) => hasCoding(observation.code?.coding, BLOOD_PRESSURE_PANEL_CODES))
    .sort(sortByObservationDateDesc)

  for (const observation of candidates) {
    const systolic = observation.component?.find((component) =>
      hasCoding(component.code?.coding, SYSTOLIC_BP_CODES),
    )?.valueQuantity
    const diastolic = observation.component?.find((component) =>
      hasCoding(component.code?.coding, DIASTOLIC_BP_CODES),
    )?.valueQuantity

    if (systolic?.value != null && diastolic?.value != null) {
      return {
        title: 'Blood pressure',
        secondaryText: `${systolic.value}/${diastolic.value} ${systolic.unit || 'mmHg'}`,
        dateLabel: 'Observed',
        dateValue: formatDate(getObservationDate(observation)),
      }
    }
  }

  return null
}

function getLatestQuantityObservation(
  observations: Observation[],
  codes: Set<string>,
) {
  return observations
    .filter((observation) => hasCoding(observation.code?.coding, codes))
    .filter((observation) => observation.valueQuantity?.value != null)
    .sort(sortByObservationDateDesc)[0]
}

function quantityObservationToItem(
  title: string,
  observation: Observation,
): ClinicalListItem {
  return {
    title,
    secondaryText: formatQuantity(observation.valueQuantity),
    dateLabel: 'Observed',
    dateValue: formatDate(getObservationDate(observation)),
  }
}

function formatQuantity(quantity: Quantity | undefined) {
  if (quantity?.value == null) return placeholderValue()
  return `${quantity.value} ${quantity.unit || ''}`.trim()
}

function hasCoding(coding: Coding[] | undefined, codes: Set<string>) {
  return coding?.some((item) => Boolean(item.code && codes.has(item.code))) ?? false
}

function getObservationDate(observation: Observation) {
  return (
    observation.effectiveDateTime ||
    observation.issued ||
    observation.meta?.lastUpdated ||
    undefined
  )
}

function sortByObservationDateDesc(a: Observation, b: Observation) {
  const aDate = Date.parse(getObservationDate(a) || '')
  const bDate = Date.parse(getObservationDate(b) || '')
  return bDate - aDate
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}
