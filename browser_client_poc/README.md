# PACIO POC Standalone Browser Client

The goal of this area of the pseudo-ehr is to explore the cost and value of a PACIO (https://pacioproject.org/) reference implementation that

* Has no code or dependency relationship on the existing pseudo-ehr Ruby on Rails reference implementation
* Uses standard TypeScript and web app infrastructure (Vite, React) that may be more accessible as a reference implementation than Ruby and Rails
* Removes the reliance on a backend application server, allowing hosting of FHIR client functionality on GitHub pages
* Focuses more on providing a clear and declarative reference implementation without some of the complex overhead of the Ruby on Rails implementation (e.g., caching, multilevel job and API infrastructure)

The initial application exploration will

* Start with Vite, Typescript, React
* Use @types/fhir and fhirpath.js to simplify implementation
* Interact with FHIR servers using standard JS fetch to get resources

## First Steps

Application development will take the following steps:

1. Connect to a FHIR server (the app keeps a list of previously used FHIR servers and a short reference name for each in browser local storage)
2. List the Patient records on the server
3. Allow the user to filter or search for patients
4. When a patient is selected
   1. That patient's full record is loaded (using $everything operator)
   2. A patient summary page is displayed

## Proposed architectural choices

The goal is to have a clear reference implementation that is easy to follow but still use abstractions to simplify code. For example, custom React Hooks may be helpful to handle loading states, error boundaries, or fetching additional dependent data (like fetching a patient's Observations automatically whenever a patient view loads), e.g., something like

import { useMemo } from 'react';
import { Patient } from 'fhir/r4';
import { getPatientFullName, getPatientPhone } from '../utils/fhirHelpers';

export const usePatientModel = (patient: Patient | undefined) => {
  return useMemo(() => {
    if (!patient) return null;

    return {
      // Expose the raw data if a specific view needs custom hacking
      raw: patient,
      // Expose the clean semantic helper methods/fields
      fullName: getPatientFullName(patient),
      primaryPhone: getPatientPhone(patient),
      birthDate: patient.birthDate || 'Not Recorded'
    };
  }, [patient]); // Only recalculates if the actual patient object changes
};

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
