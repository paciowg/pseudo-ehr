# PACIO POC Standalone Browser Client

The goal of this area of the pseudo-ehr is to explore the cost and value of a PACIO (https://pacioproject.org/) demonstration and reference implementation that

* Has no code or dependency relationship on the existing pseudo-ehr Ruby on Rails reference implementation
* Uses standard TypeScript and web app infrastructure (Vite, React) that may be more accessible as a reference implementation than Ruby and Rails
* Removes the reliance on a backend application server, allowing hosting of FHIR client functionality on GitHub pages
* Focuses more on providing a clear and declarative reference implementation without some of the complex overhead of the Ruby on Rails implementation (e.g., caching, multilevel job and API infrastructure)

The initial application exploration will

* Start with Vite, Typescript, React
* Use `@types/fhir`
* Interact with FHIR servers using standard browser `fetch`
* Support only open FHIR R4 endpoints to start with

## Phase 1

Initial application development supports the following:

1. Connect to a FHIR server
2. Keep a list of previously used FHIR servers and a short reference name for each in browser local storage
3. List up to 100 Patient records on the active server
4. Allow the user to filter or search for patients client-side
5. When a patient is selected
   1. That patient's full record is loaded primarily using `$everything`
   2. If `$everything` fails, the app falls back to `Patient/{id}`
   3. A patient summary page is displayed
6. When an advance directive is selected from the patient summary
   1. The app loads `DocumentReference/{id}`
   2. A generic advance directive detail page is displayed

Phase 1 is read-only.

The patient summary displays:

- personal information
- contact information
- demographics
- emergency contacts
- active problems
- current medications
- known allergies
- most recent vitals
- advance directives

The initial clinical summary sections are non-interactive except for Advance Directives, which support selection and drill-in to a detail page. Each section shows up to 10 items with dates where available and clear empty states.

Display conventions:

- missing scalar values: `--`
- empty loaded lists: `None recorded`
- unavailable bundle-derived sections: `Unavailable`

Routing uses a small hash-based route switch:

- `#/`
- `#/patients`
- `#/patients/:id`
- `#/patients/:id/advance-directives/:documentReferenceId`

This keeps the app simple and friendly to static hosting environments.

Phase 1 should be completed in a manner that supports future PACIO reference capabilities in later iterations.

For more detailed planning and current decisions, see:

- `IMPLEMENTATION_PLAN.md`

## Phase 2

Once basic FHIR support is in place some PACIO specific functionality will be explored. Candidates include:

1. Transition of Care document bundle builder
2. Advanced Directive document bundle builder

## Proposed architectural choices

The goal is to have a clear reference implementation that is easy to follow but still use abstractions to simplify code.

Current structure:

- `src/lib/fhir/` for FHIR fetch and formatting helpers
- `src/lib/routing/` for hash route parsing and navigation
- `src/features/servers/` for saved server state and connection flow
- `src/features/patients/` for patient list loading and filtering
- `src/features/patientSummary/` for patient summary derivation, rendering, and advance directive detail pages
- `src/components/` for reusable presentational components

## Running the app

Start the Vite dev server in `browser_client_poc/` and open the app in a browser. The app connects directly to the configured FHIR server from the browser, so the selected demo server must allow browser access and CORS for:

- `GET /metadata`
- `GET /Patient?_count=100`
- `GET /Patient/{id}`
- `GET /Patient/{id}/$everything`
- `GET /DocumentReference/{id}`

# React + TypeScript + Vite

This was created as a template that provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend enabling type-aware lint rules by installing `oxlint-tsgolint` and editing `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc"],
  "options": {
    "typeAware": true
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }]
  }
}
```

See the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules) for the full list of rules and categories.
