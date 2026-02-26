Initial sketch of supporting SMP operations in a HAPI FHIR server

Build the operation JAR:

```bash
mvn clean package
```

Run the docker image with the operation included:

```bash
docker compose up
```

## Operations

### $smp-query (Retrieve)

Test by POSTing a Patient resource to `http://localhost:8081/fhir/$smp-query`.

Example request body:
```json
{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "patient",
      "resource": {
        "resourceType": "Patient",
        "identifier": [{ "system": "http://hospital.org", "value": "123" }]
      }
    }
  ]
}
```

### $smp-submit (Submit)

Test by POSTing a Bundle resource to `http://localhost:8081/fhir/$smp-submit`.

Example request body:
```json
{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "smp-medication-data",
      "resource": {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
          {
            "resource": {
              "resourceType": "Patient",
              "identifier": [{ "system": "http://hospital.org", "value": "123" }]
            }
          },
          {
            "resource": {
              "resourceType": "MedicationStatement",
              "status": "active",
              "medicationCodeableConcept": {
                "coding": [{ "system": "http://www.nlm.nih.gov/research/umls/rxnorm", "code": "284429", "display": "Aspirin 81 MG Oral Tablet" }]
              },
              "subject": { "reference": "Patient/1" }
            }
          }
        ]
      }
    }
  ]
}
```

## Testing with Ruby scripts

Helper scripts are provided in the `scripts/` directory to test the operations.

### test_smp_query.rb

It takes a JSON file containing a Patient resource and sends it to the server wrapped in the required Parameters resource.

```bash
ruby scripts/test_smp_query.rb <path_to_patient_json> <server_url>
```

Example:
```bash
# Create a dummy patient file
echo '{"resourceType":"Patient","identifier":[{"system":"http://hospital.org","value":"123"}]}' > patient.json

# Run the test script
ruby scripts/test_smp_query.rb patient.json http://localhost:8081/fhir
```

### test_smp_submit.rb

It takes a JSON file containing a Bundle resource and sends it to the server wrapped in the required Parameters resource.

```bash
ruby scripts/test_smp_submit.rb <path_to_bundle_json> <server_url>
```

Example:
```bash
# Create a dummy bundle file
echo '{"resourceType":"Bundle","type":"transaction","entry":[{"resource":{"resourceType":"Patient","identifier":[{"system":"http://hospital.org","value":"123"}]}},{"resource":{"resourceType":"MedicationStatement","status":"active","medicationCodeableConcept":{"coding":[{"system":"http://www.nlm.nih.gov/research/umls/rxnorm","code":"284429"}]}}}]}' > bundle.json

# Run the test script
ruby scripts/test_smp_submit.rb bundle.json http://localhost:8081/fhir
```
