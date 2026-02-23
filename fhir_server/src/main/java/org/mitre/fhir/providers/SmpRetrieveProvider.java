package org.mitre.fhir.providers;

import ca.uhn.fhir.jpa.api.dao.IFhirResourceDao;
import ca.uhn.fhir.jpa.searchparam.SearchParameterMap;
import ca.uhn.fhir.rest.annotation.Operation;
import ca.uhn.fhir.rest.annotation.OperationParam;
import ca.uhn.fhir.rest.api.server.IBundleProvider;
import ca.uhn.fhir.rest.param.DateParam;
import ca.uhn.fhir.rest.param.ReferenceParam;
import ca.uhn.fhir.rest.param.StringParam;
import ca.uhn.fhir.rest.param.TokenParam;
import org.hl7.fhir.instance.model.api.IBaseResource;
import org.hl7.fhir.r4.model.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SmpRetrieveProvider {

    @Autowired
    private IFhirResourceDao<Patient> myPatientDao;

    @Autowired
    private IFhirResourceDao<MedicationStatement> myMedicationStatementDao;

    @Autowired
    private IFhirResourceDao<MedicationRequest> myMedicationRequestDao;

    @Autowired
    private IFhirResourceDao<MedicationDispense> myMedicationDispenseDao;

    @Autowired
    private IFhirResourceDao<MedicationAdministration> myMedicationAdministrationDao;

    /**
     * The Operation Definition: $smp-query
     * URL: [base]/$smp-query
     */
    @Operation(name = "$smp-query", idempotent = true)
    public Parameters smpOperationRetrieve(
            @OperationParam(name = "patient") Patient thePatient,
            @OperationParam(name = "list-type") CodeableConcept theListType
    ) {
        // 1. Validate inputs
        if (thePatient == null) {
            throw new IllegalArgumentException("Patient parameter is required");
        }

        // Note: list-type is ignored for now as per requirements
        // if (theListType != null) { ... }

        // 2. Logic: Search for matching patient
        // We'll try to match by identifier first, then by name and birthdate
        SearchParameterMap map = new SearchParameterMap();
        boolean hasCriteria = false;

        if (thePatient.hasIdentifier()) {
            Identifier id = thePatient.getIdentifierFirstRep();
            map.add(Patient.SP_IDENTIFIER, new TokenParam(id.getSystem(), id.getValue()));
            hasCriteria = true;
        } else {
            if (thePatient.hasName()) {
                HumanName name = thePatient.getNameFirstRep();
                if (name.hasFamily()) {
                    map.add(Patient.SP_FAMILY, new StringParam(name.getFamily()));
                    hasCriteria = true;
                }
                if (name.hasGiven()) {
                    map.add(Patient.SP_GIVEN, new StringParam(name.getGivenAsSingleString()));
                    hasCriteria = true;
                }
            }
            if (thePatient.hasBirthDate()) {
                // Using setValue() explicitly to avoid constructor ambiguity with java.util.Date
                map.add(Patient.SP_BIRTHDATE, new DateParam().setValue(thePatient.getBirthDate()));
                hasCriteria = true;
            }
        }

        Bundle resultBundle = new Bundle();
        resultBundle.setType(Bundle.BundleType.COLLECTION); // IG specifies 'collection' type for the output bundle

        OperationOutcome outcome = new OperationOutcome();

        if (!hasCriteria) {
            outcome.addIssue()
                    .setSeverity(OperationOutcome.IssueSeverity.ERROR)
                    .setCode(OperationOutcome.IssueType.INVALID)
                    .setDiagnostics("No search criteria (identifier, name, or birthdate) found in input patient resource.");
        } else {
            IBundleProvider searchResults = myPatientDao.search(map);
            List<IBaseResource> patients = searchResults.getResources(0, 1);

            if (patients.isEmpty()) {
                outcome.addIssue()
                        .setSeverity(OperationOutcome.IssueSeverity.WARNING)
                        .setCode(OperationOutcome.IssueType.NOTFOUND)
                        .setDiagnostics("No matching patient found.");
            } else {
                // Take the first match
                Patient matchedPatient = (Patient) patients.get(0);
                resultBundle.addEntry().setResource(matchedPatient);

                // Create the Medication List resource (SMPMedicationList)
                ListResource medList = new ListResource();
                medList.setStatus(ListResource.ListStatus.CURRENT);
                medList.setMode(ListResource.ListMode.SNAPSHOT);
                // LOINC 10160-0: History of Medication use
                medList.setCode(new CodeableConcept().addCoding(new Coding("http://loinc.org", "10160-0", "History of Medication use")));
                medList.setSubject(new Reference(matchedPatient.getIdElement().toUnqualifiedVersionless()));

                // Fetch MedicationStatements
                SearchParameterMap msMap = new SearchParameterMap();
                msMap.add(MedicationStatement.SP_PATIENT, new ReferenceParam(matchedPatient.getIdElement().toUnqualifiedVersionless()));
                List<IBaseResource> statements = myMedicationStatementDao.search(msMap).getResources(0, 100);
                for (IBaseResource res : statements) {
                    MedicationStatement ms = (MedicationStatement) res;
                    medList.addEntry().setItem(new Reference(ms.getIdElement().toUnqualifiedVersionless()));
                    resultBundle.addEntry().setResource(ms);
                }

                // Add the List to the bundle
                resultBundle.addEntry().setResource(medList);

                // Fetch other medication resources and add to bundle
                
                // MedicationRequest
                SearchParameterMap mrMap = new SearchParameterMap();
                mrMap.add(MedicationRequest.SP_PATIENT, new ReferenceParam(matchedPatient.getIdElement().toUnqualifiedVersionless()));
                List<IBaseResource> requests = myMedicationRequestDao.search(mrMap).getResources(0, 100);
                for (IBaseResource res : requests) {
                    resultBundle.addEntry().setResource((MedicationRequest) res);
                }

                // MedicationDispense
                SearchParameterMap mdMap = new SearchParameterMap();
                mdMap.add(MedicationDispense.SP_PATIENT, new ReferenceParam(matchedPatient.getIdElement().toUnqualifiedVersionless()));
                List<IBaseResource> dispenses = myMedicationDispenseDao.search(mdMap).getResources(0, 100);
                for (IBaseResource res : dispenses) {
                    resultBundle.addEntry().setResource((MedicationDispense) res);
                }

                // MedicationAdministration
                SearchParameterMap maMap = new SearchParameterMap();
                maMap.add(MedicationAdministration.SP_PATIENT, new ReferenceParam(matchedPatient.getIdElement().toUnqualifiedVersionless()));
                List<IBaseResource> admins = myMedicationAdministrationDao.search(maMap).getResources(0, 100);
                for (IBaseResource res : admins) {
                    resultBundle.addEntry().setResource((MedicationAdministration) res);
                }

                if (searchResults.size() != null && searchResults.size() > 1) {
                    outcome.addIssue()
                            .setSeverity(OperationOutcome.IssueSeverity.INFORMATION)
                            .setCode(OperationOutcome.IssueType.INFORMATIONAL)
                            .setDiagnostics("Multiple matches found. Returning the first match. (Future improvement: leverage EMPI for better matching)");
                } else {
                    outcome.addIssue()
                            .setSeverity(OperationOutcome.IssueSeverity.INFORMATION)
                            .setCode(OperationOutcome.IssueType.INFORMATIONAL)
                            .setDiagnostics("Patient match successful and medication data retrieved.");
                }
            }
        }

        // 3. Construct Response
        Parameters response = new Parameters();
        
        response.addParameter()
                .setName("smp-medication-data")
                .setResource(resultBundle);

        response.addParameter()
                .setName("outcome")
                .setResource(outcome);

        return response;
    }
}
