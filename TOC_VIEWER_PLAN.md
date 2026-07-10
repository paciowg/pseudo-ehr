# TOC Bundle Viewer Plan

This document captures the implementation plan for building a viewer for TOC Bundles in the existing `DocumentReferences` bundle view flow.

## Goal

Build a TOC Bundle viewer that displays:

- top-level document context
  - bundle/composition title
  - basic patient (subject) information
  - author
  - custodian if present
- all sections of the TOC Composition
- basic readable content for each section

Examples:

- `medical_devices` should list each referenced `Device` with device name and other basic information.
- `medications` should list medication-related entries with readable names and other basic information.

## Current implementation context

We already have:

- a `bundle` action in `DocumentReferencesController` that loads a `FHIR::Bundle`
- a helper file:
  - `app/helpers/document_references_helper.rb`
- a view file:
  - `app/views/document_references/bundle.html.erb`

## Implementation principles

### 1. Keep controller logic minimal

The controller should continue to load `@bundle` and handle errors, but should not contain TOC parsing or bundle traversal logic.

### 2. Put bundle parsing/navigation in helpers

All logic for:

- finding the Composition
- traversing `bundle.entry`
- resolving references within the bundle
- extracting resource data
- formatting section display structures

should live in `app/helpers/document_references_helper.rb`.

### 3. Keep the view relatively slim

The view should primarily:

- display high-level bundle context
- iterate through precomputed section data
- render items returned by helper methods

The view should avoid heavy conditional logic or direct FHIR traversal where possible.

## High-level approach

The cleanest implementation is:

1. Continue loading `@bundle` in the controller
2. Add TOC-specific helper methods in `DocumentReferencesHelper`
3. Build display-ready normalized hashes/arrays in helpers
4. Render those structures in `bundle.html.erb`

## Recommended helper API

### Top-level bundle helpers

Suggested helper methods:

- `toc_composition(bundle)`
- `toc_bundle_title(bundle)`
- `toc_bundle_subject(bundle)`
- `toc_bundle_author(bundle)`
- `toc_bundle_custodian(bundle)`
- `toc_bundle_sections(bundle)`

### Reference resolution helpers

These will be the foundation for navigating the bundle:

- `bundle_entries(bundle)`
- `bundle_resource_index(bundle)`
- `resolve_bundle_reference(bundle, reference)`
- `resolve_section_entry_resources(bundle, section)`

These are important because the sample bundle uses many:

- `urn:uuid:...`
- potentially relative references like `Patient/123`
- potentially absolute references

### Section formatting helpers

Add a normalized section formatter:

- `toc_sections_for_display(bundle)`

This should return display-ready section hashes, for example:

