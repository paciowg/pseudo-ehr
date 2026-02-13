Initial sketch of supporting SMP operations in a HAPI FHIR server

Build the operation JAR:

```bash
mvn clean package
```

Run the docker image with the operation included:

```bash
docker compose up
```

Test by visiting http://localhost:8081/fhir/$smp-query?patient=Patient/123
