import type { Address, CodeableConcept, ContactPoint, HumanName, Identifier } from 'fhir/r4'

export function placeholderValue() {
  return '--'
}

export function getDisplayNameFromHumanName(name: HumanName | undefined) {
  if (!name) return ''

  if (name.text?.trim()) return name.text.trim()

  const given = (name.given ?? []).join(' ').trim()
  const family = name.family?.trim() || ''
  return [given, family].filter(Boolean).join(' ').trim()
}

export function getFirstMrn(identifiers: Identifier[] | undefined) {
  return identifiers?.find((identifier) =>
    identifier.type?.coding?.some((coding) => coding.code === 'MR'),
  )?.value
}

export function formatPhone(telecom: ContactPoint[] | undefined) {
  const phone = telecom?.find((item) => item.system === 'phone')?.value
  return phone || placeholderValue()
}

export function formatAddress(address: Address | undefined) {
  if (!address) return placeholderValue()
  if (address.text?.trim()) return address.text.trim()

  const lines = [
    ...(address.line ?? []),
    address.city,
    address.state,
    address.postalCode,
    address.country,
  ].filter(Boolean)

  return lines.length > 0 ? lines.join(', ') : placeholderValue()
}

export function getCodeableConceptText(codeableConcept: CodeableConcept | undefined) {
  return (
    codeableConcept?.text ||
    codeableConcept?.coding?.[0]?.display ||
    codeableConcept?.coding?.[0]?.code ||
    ''
  )
}

export function formatDate(value: string | undefined) {
  return value || placeholderValue()
}
