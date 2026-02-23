Initial sketch of supporting SMP operations in a HAPI FHIR server

Build the operation JAR:

```bash
mvn clean package
```

Run the docker image with the operation included:

```bash
docker compose up
```

Test by POSTing a Patient resource to http://localhost:8081/fhir/$smp-query

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

### Testing with Ruby script

A helper script is provided in `scripts/test_smp_query.rb` to test the operation. It takes a JSON file containing a Patient resource and sends it to the server wrapped in the required Parameters resource.

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
