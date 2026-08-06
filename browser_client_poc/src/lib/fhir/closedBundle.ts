import type { Bundle, BundleEntry, Resource } from 'fhir/r4'
import { fetchResourceByReference } from './client'
import { getBundleResourceReferences } from './bundleReferences'

type ResourceWithId = Resource & { id: string }

function buildResourceKey(resource: ResourceWithId) {
  return `${resource.resourceType}/${resource.id}`
}

function cloneBundle(bundle: Bundle): Bundle {
  return JSON.parse(JSON.stringify(bundle)) as Bundle
}

function getIncludedReferenceSet(bundle: Bundle) {
  const included = new Set<string>()

  for (const entry of bundle.entry ?? []) {
    const resource = entry.resource
    if (!resource?.resourceType || !resource.id) continue
    included.add(buildResourceKey(resource as ResourceWithId))
  }

  return included
}

export async function closeBundleReferences(baseUrl: string, bundle: Bundle): Promise<Bundle> {
  const nextBundle = cloneBundle(bundle)
  const includedReferences = getIncludedReferenceSet(nextBundle)
  const fetchedReferences = new Set<string>()

  while (true) {
    const references = Array.from(getBundleResourceReferences(nextBundle))
    const unresolvedReferences = references.filter(
      (reference) =>
        !includedReferences.has(reference) && !fetchedReferences.has(reference),
    )

    if (unresolvedReferences.length === 0) {
      break
    }

    for (const reference of unresolvedReferences) {
      const resource = await fetchResourceByReference(baseUrl, reference)

      if (!resource.id || !resource.resourceType) {
        throw new Error(`Unable to resolve required bundle reference: ${reference}`)
      }

      const resolvedReference = `${resource.resourceType}/${resource.id}`
      includedReferences.add(resolvedReference)
      fetchedReferences.add(reference)

      const entry: BundleEntry = {
        fullUrl: resolvedReference,
        resource,
      }

      nextBundle.entry = [...(nextBundle.entry ?? []), entry]
    }
  }

  const remainingExternalReferences = Array.from(getBundleResourceReferences(nextBundle)).filter(
    (reference) => !includedReferences.has(reference),
  )

  if (remainingExternalReferences.length > 0) {
    throw new Error(
      `Unable to create a closed bundle. Unresolved references: ${remainingExternalReferences.join(', ')}`,
    )
  }

  return nextBundle
}
