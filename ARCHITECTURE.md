# Architecture Documentation

## FHIR Resource Management

This application acts as an EHR-standin that fetches, organizes, and caches FHIR patient data. It uses a two-tier caching strategy and a lazy-loading "wrapping" mechanism to transform raw FHIR data into Ruby objects that behave like Rails models.

### 1. Connection and Authentication
Before data can be fetched, the application establishes a secure connection to a FHIR server.
- **Model**: `app/models/fhir_server.rb` stores the base URL and OAuth2 credentials (client ID, secret, tokens).
- **Service**: `app/services/fhir_client_service.rb` initializes the `FHIR::Client` and handles token refreshes or SMART-on-FHIR launch sequences.
- **Extension**: `config/initializers/fhir_client.rb` extends the base `FHIR::Client` from the `fhir-models` gem to support specific search parameters and the `$everything` operation.

### 2. Initial Data Ingestion (The Bulk Load)
When a patient is selected, the application performs a bulk fetch to minimize subsequent API calls.
- **Trigger**: `PatientsController#show` (in `app/controllers/patients_controller.rb`) sets the `session[:patient_id]` and calls `retrieve_current_patient_resources`.
- **Orchestration**: `ApplicationController#retrieve_current_patient_resources` (in `app/controllers/application_controller.rb`) checks the cache and, if empty, triggers the fetch.
- **Fetching Logic**: `ResourceFetchHelper#fetch_single_patient_record` (in `app/helpers/resource_fetch_helper.rb`) executes the FHIR request. It uses a broad search (often `$everything` or `_include: '*'`) to get a comprehensive Bundle.

### 3. Tier 1 Cache: Raw Resource Storage
The raw results from the FHIR server are stored in their original form to allow for flexible re-parsing.
- **Storage**: `app/models/patient_record_cache.rb` stores raw `FHIR::Resource` objects in class-level hashes indexed by `patient_id`.
- **Organization**: Data is grouped by `resourceType` (e.g., all "Observation" resources are grouped together) for fast retrieval via `PatientRecordCache.get_grouped_patient_record`.

### 4. Transformation: The "Wrapping" Process
Raw FHIR objects are transformed into custom Ruby models (e.g., `Observation`, `Condition`) on-demand. This is known as "wrapping."
- **The Trigger**:
    - **Resource Controllers**: When a user visits a list view (e.g., `ObservationsController#index`), the controller iterates over raw cached resources and calls the model constructor (e.g., `Observation.new(raw_resource, bundle_entries)`).
    - **Summary Models**: Complex models like `Composition` (in `app/models/composition.rb`) or `Encounter` (in `app/models/encounter.rb`) wrap related resources automatically as they resolve references in the FHIR bundle.
- **Parsing Logic**: `app/models/concerns/model_helper.rb` provides shared methods to flatten complex FHIR structures (like `CodeableConcepts`, `Names`, or `Addresses`) into simple Ruby attributes.
- **Reference Resolution**: During initialization, models use the `bundle_entries` (the full set of patient resources) to resolve internal references, such as finding a Practitioner's name for a specific Performer ID.

### 5. Tier 2 Cache: Modeled Object Storage
Once a resource is wrapped, it is cached as a Ruby object to avoid redundant parsing.
- **Base Class**: `app/models/resource.rb` defines the `update` method.
- **Mechanism**: Every custom model calls `self.class.update(self)` at the end of its `initialize` method. This adds the instance to a class-level `@all` array and `@all_by_id` hash.
- **Retrieval**: Subsequent calls to `Observation.find(id)` or `Observation.filter_by_patient_id(id)` return the already-modeled objects from this memory space.

### 6. Global Resource Management
Resources not specific to a single patient (e.g., `Organization`, `Location`) are handled separately.
- **Storage**: `app/models/other_resource_cache.rb` manages these shared resources.
- **Lifecycle**: These are typically loaded once per session or until they expire (default 1 hour), preventing the app from re-fetching hospital or provider details for every patient record.

### Summary of Key Files
| File | Responsibility |
| :--- | :--- |
| `app/controllers/application_controller.rb` | High-level orchestration of data loading and resource counting. |
| `app/helpers/resource_fetch_helper.rb` | Low-level FHIR API request construction and execution. |
| `app/models/patient_record_cache.rb` | Tier 1 Cache: Stores raw `FHIR::Resource` objects. |
| `app/models/resource.rb` | Tier 2 Cache: Base class managing modeled object storage. |
| `app/models/concerns/model_helper.rb` | Shared parsing logic for FHIR data types. |
| `app/services/fhir_client_service.rb` | Connection management and OAuth2 authentication. |
