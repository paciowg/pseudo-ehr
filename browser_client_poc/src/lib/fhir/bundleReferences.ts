import type { Bundle, BundleEntry, Resource } from 'fhir/r4'

type ResourceWithId = Resource & { id: string }

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function isResourceWithId(resource: Resource | undefined): resource is ResourceWithId {
  return Boolean(resource?.resourceType && resource?.id)
}

function buildResourceKey(resource: ResourceWithId) {
  return `${resource.resourceType}/${resource.id}`
}

function cloneBundle(bundle: Bundle): Bundle {
  return JSON.parse(JSON.stringify(bundle)) as Bundle
}

function replaceInternalReferences(
  node: unknown,
  fullUrlByReference: Map<string, string>,
) {
  if (Array.isArray(node)) {
    for (const item of node) {
      replaceInternalReferences(item, fullUrlByReference)
    }
    return
  }

  if (!isObject(node)) {
    return
  }

  const referenceValue = node.reference
  if (
    typeof referenceValue === 'string' &&
    !referenceValue.startsWith('#') &&
    fullUrlByReference.has(referenceValue)
  ) {
    node.reference = fullUrlByReference.get(referenceValue)
  }

  for (const value of Object.values(node)) {
    replaceInternalReferences(value, fullUrlByReference)
  }
}

export function getBundleResourceReferences(bundle: Bundle) {
  const references = new Set<string>()

  function collectReferences(node: unknown) {
    if (Array.isArray(node)) {
      for (const item of node) {
        collectReferences(item)
      }
      return
    }

    if (!isObject(node)) {
      return
    }

    const referenceValue = node.reference
    if (
      typeof referenceValue === 'string' &&
      !referenceValue.startsWith('#') &&
      !referenceValue.startsWith('urn:uuid:') &&
      !referenceValue.includes('://') &&
      referenceValue.includes('/')
    ) {
      references.add(referenceValue)
    }

    for (const value of Object.values(node)) {
      collectReferences(value)
    }
  }

  for (const entry of bundle.entry ?? []) {
    if (entry.resource) {
      collectReferences(entry.resource)
    }
  }

  return references
}

export function withUrnUuidBundleReferences(bundle: Bundle): Bundle {
  const nextBundle = cloneBundle(bundle)
  const fullUrlByReference = new Map<string, string>()

  for (const entry of nextBundle.entry ?? []) {
    const resource = entry.resource
    if (!isResourceWithId(resource)) continue

    fullUrlByReference.set(buildResourceKey(resource), `urn:uuid:${crypto.randomUUID()}`)
  }

  const nextEntries: BundleEntry[] = (nextBundle.entry ?? []).map((entry) => {
    const resource = entry.resource

    if (!isResourceWithId(resource)) {
      return entry
    }

    const resourceFullUrl = fullUrlByReference.get(buildResourceKey(resource))

    return {
      ...entry,
      fullUrl: resourceFullUrl,
    }
  })

  for (const entry of nextEntries) {
    if (entry.resource) {
      replaceInternalReferences(entry.resource, fullUrlByReference)
    }
  }

  return {
    ...nextBundle,
    entry: nextEntries,
  }
}
