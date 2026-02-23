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
