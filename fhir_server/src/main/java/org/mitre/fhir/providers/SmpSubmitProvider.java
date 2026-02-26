package org.mitre.fhir.providers;

import ca.uhn.fhir.jpa.api.dao.IFhirResourceDao;
import ca.uhn.fhir.rest.annotation.Operation;
import ca.uhn.fhir.rest.annotation.OperationParam;
import ca.uhn.fhir.rest.server.exceptions.ResourceNotFoundException;
import org.hl7.fhir.r4.model.*;
import org.mitre.fhir.services.SmpPatientService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class SmpSubmitProvider {

    @Autowired
    private SmpPatientService smpPatientService;

    @Autowired
    private IFhirResourceDao<MedicationStatement> myMedicationStatementDao;

    @Autowired
    private IFhirResourceDao<MedicationRequest> myMedicationRequestDao;

    @Autowired
    private IFhirResourceDao<MedicationDispense> myMedicationDispenseDao;

    @Autowired
    private IFhirResourceDao<MedicationAdministration> myMedicationAdministrationDao;

    /**
     * The Operation Definition: $smp-submit
     * URL: [base]/$smp-submit
     */
    @Operation(name = "$smp-submit")
    public Parameters smpOperationSubmit(
            @OperationParam(name = "smp-medication-data") Bundle theBundle
    ) {
        if (theBundle == null) {
            throw new IllegalArgumentException("smp-medication-data parameter is required");
        }

        // 1. Find the Patient resource in the bundle to use for matching
        Patient templatePatient = theBundle.getEntry().stream()
                .filter(e -> e.getResource() instanceof Patient)
                .map(e -> (Patient) e.getResource())
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Bundle must contain a Patient resource for matching."));

        // 2. Match Patient
        SmpPatientService.PatientMatchResult matchResult = smpPatientService.findMatchingPatient(templatePatient);
        Patient matchedPatient = matchResult.getPatient();
        if (matchedPatient == null) {
            // Requirement: Don't create a new patient, return a 404
            throw new ResourceNotFoundException("No matching patient found. Submit aborted.");
        }

        Reference patientRef = new Reference(matchedPatient.getIdElement().toUnqualifiedVersionless());
        int count = 0;

        // 3. Iterate and save resources
        // TODO: Wrap this in a proper transaction for atomicity (Requirement 5)
        for (Bundle.BundleEntryComponent entry : theBundle.getEntry()) {
            Resource res = entry.getResource();
            
            if (res instanceof Patient || res instanceof ListResource) {
                // TODO: Re-evaluate if ListResource should be persisted (Requirement 4)
                continue;
            }

            // Update IDs to attach to the matched patient (Requirement 2)
            if (res instanceof MedicationStatement) {
                ((MedicationStatement) res).setSubject(patientRef);
                // TODO: Check for existing records instead of creating duplicates (Requirement 3)
                myMedicationStatementDao.create((MedicationStatement) res);
                count++;
            } else if (res instanceof MedicationRequest) {
                ((MedicationRequest) res).setSubject(patientRef);
                myMedicationRequestDao.create((MedicationRequest) res);
                count++;
            } else if (res instanceof MedicationDispense) {
                ((MedicationDispense) res).setSubject(patientRef);
                myMedicationDispenseDao.create((MedicationDispense) res);
                count++;
            } else if (res instanceof MedicationAdministration) {
                ((MedicationAdministration) res).setSubject(patientRef);
                myMedicationAdministrationDao.create((MedicationAdministration) res);
                count++;
            }
        }

        OperationOutcome outcome = new OperationOutcome();
        outcome.addIssue()
                .setSeverity(OperationOutcome.IssueSeverity.INFORMATION)
                .setCode(OperationOutcome.IssueType.INFORMATIONAL)
                .setDiagnostics("Successfully processed " + count + " medication resources for patient: " + matchedPatient.getIdElement().getIdPart());

        Parameters response = new Parameters();
        response.addParameter().setName("outcome").setResource(outcome);
        return response;
    }
}
