################################################################################
#
# Constants
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

DEFAULT_SERVER = "http://hapi.fhir.org/baseR4"
#DEFAULT_SERVER = "http://data-mgr.azurewebsites.net/open"
HEALTH_DATA_MGR = "https://data-mgr.azurewebsites.net/open2"
#HEALTH_DATA_MGR = "http://hapi.fhir.org/baseR4"
EHR_FHIR_SERVER = "https://api.logicahealth.org/mCODEv1/open"
#EHR_FHIR_SERVER = "http://hapi.fhir.org/baseR4"

CODE_MAPPING = { 
            "Section-3/C1610" => { 
              system: "http://loinc.org", 
              code: "86585-7", 
              display: "Signs and symptoms of delirium (from CAM)" 
            },
            "Section-37/GG0130" => {
              system: "http://loinc.org",
              code: "83254-3",
              display: "Self-care - discharge performance [CMS Assessment]"
            },
            "Section-37/GG0170" => {
              system: "http://loinc.org",
              code: "88331-4", 
              display: "Mobility - discharge performance during 3 day assessment period [CMS Assessment]"
            } 
          }

META_MAPPING = {
  "Section-3/C1610" => "http://pacioproject.org/StructureDefinition/pacio-bcs",
  "Section-37/GG0130" => "http://pacioproject.org/StructureDefinition/pacio-bfs",
  "Section-37/GG0170" => "http://pacioproject.org/StructureDefinition/pacio-bfs"
}