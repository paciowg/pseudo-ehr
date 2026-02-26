package org.mitre.fhir.services;

import ca.uhn.fhir.jpa.api.dao.IFhirResourceDao;
import ca.uhn.fhir.jpa.searchparam.SearchParameterMap;
import ca.uhn.fhir.rest.api.server.IBundleProvider;
import ca.uhn.fhir.rest.param.DateParam;
import ca.uhn.fhir.rest.param.StringParam;
import ca.uhn.fhir.rest.param.TokenParam;
import org.hl7.fhir.instance.model.api.IBaseResource;
import org.hl7.fhir.r4.model.HumanName;
import org.hl7.fhir.r4.model.Identifier;
import org.hl7.fhir.r4.model.Patient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SmpPatientService {

    @Autowired
    private IFhirResourceDao<Patient> myPatientDao;

    public static class PatientMatchResult {
        private final Patient patient;
        private final boolean multipleMatches;

        public PatientMatchResult(Patient patient, boolean multipleMatches) {
            this.patient = patient;
            this.multipleMatches = multipleMatches;
        }

        public Patient getPatient() {
            return patient;
        }

        public boolean hasMultipleMatches() {
            return multipleMatches;
        }
    }

    /**
     * Shared logic to find a matching patient based on identifier, name, and birthdate.
     * Returns a PatientMatchResult containing the first matching Patient (or null) and 
     * whether multiple matches were found.
     */
    public PatientMatchResult findMatchingPatient(Patient thePatient) {
        if (!hasCriteria(thePatient)) {
            return new PatientMatchResult(null, false);
        }

        SearchParameterMap map = new SearchParameterMap();

        if (thePatient.hasIdentifier()) {
            Identifier id = thePatient.getIdentifierFirstRep();
            map.add(Patient.SP_IDENTIFIER, new TokenParam(id.getSystem(), id.getValue()));
        } else {
            if (thePatient.hasName()) {
                HumanName name = thePatient.getNameFirstRep();
                if (name.hasFamily()) {
                    map.add(Patient.SP_FAMILY, new StringParam(name.getFamily()));
                }
                if (name.hasGiven()) {
                    map.add(Patient.SP_GIVEN, new StringParam(name.getGivenAsSingleString()));
                }
            }
            if (thePatient.hasBirthDate()) {
                map.add(Patient.SP_BIRTHDATE, new DateParam().setValue(thePatient.getBirthDate()));
            }
        }

        IBundleProvider searchResults = myPatientDao.search(map);
        List<IBaseResource> patients = searchResults.getResources(0, 1);

        if (patients.isEmpty()) {
            return new PatientMatchResult(null, false);
        }

        boolean multiple = searchResults.size() != null && searchResults.size() > 1;
        return new PatientMatchResult((Patient) patients.get(0), multiple);
    }

    /**
     * Checks if the provided patient resource contains enough information to perform a match.
     */
    public boolean hasCriteria(Patient thePatient) {
        if (thePatient == null) return false;
        if (thePatient.hasIdentifier()) return true;
        
        if (thePatient.hasName()) {
            HumanName name = thePatient.getNameFirstRep();
            if (name.hasFamily() || name.hasGiven()) return true;
        }
        
        return thePatient.hasBirthDate();
    }
}
