# Plan for Decoupling Sample FHIR Data

This document outlines the plan to decouple the sample FHIR data from the application's codebase. The current implementation relies on a local directory of JSON files that are scraped and loaded. The new implementation will fetch this data from a remote, web-accessible source via a manifest file.

## 1. High-Level Goals

- **Decouple Data:** Remove the local `sample_use_cases` directory from the repository.
- **Remote Data Source:** Fetch sample data from a remote manifest file (`manifest.json`).
- **User Experience:** Allow users to select from different versions (releases) of the sample data.
- **Maintain Functionality:** Preserve the ability to view sample data and push it to a FHIR server.
- **Improve Architecture:** Use background jobs for long-running tasks and create reusable services for core logic.

---

## 2. New Components and Architecture

### New Services

1.  **`SampleDataService` (`app/services/sample_data_service.rb`)**
    -   **Purpose:** To be the single source of truth for fetching and parsing the remote sample data manifest and files.
    -   **Responsibilities:**
        -   Fetch and cache the `manifest.json` file.
        -   Provide a list of available releases (e.g., "PACIO Sample Data v0.2", "master").
        -   Structure the data for a given release into the nested hash format required by the views (`scenes -> resource_types -> resources`).
        -   Fetch and cache the content of an individual resource JSON file from its URL (e.g., via a `fetch_resource_content(url)` method) to preserve the file viewer functionality on the `sample_data/index` page.

2.  **`FhirPushService` (`app/services/fhir_push_service.rb`)**
    -   **Purpose:** To encapsulate the logic for pushing a set of FHIR resources to a server.
    -   **Responsibilities:**
        -   Accept a list of resource URLs, a target FHIR server URL, and a `TaskStatus` record.
        -   Iterate through the URLs, download each resource.
        -   Perform the PUT request to the FHIR server.
        -   Update the `TaskStatus` record with progress, success, or failure messages.
        -   This logic will be extracted from the existing `fhir:push` Rake task. The complex dependency graph logic (`extract_references`, `topological_sort`) in the Rake task should be discarded. The new service will use a simpler, more robust retry strategy:
            -   Don't build an explicit dependency map.
            -   Try resources most likely to not have dependencies first (e.g., Location, Practitioner, Patient).
            -   Retry each resource up to 5 times, and on failure, add it to the end of the queue of resources to add rather than retrying immediately.

### New Background Job

1.  **`FhirDataPushJob` (`app/jobs/fhir_data_push_job.rb`)**
    -   **Purpose:** To execute the data push as an asynchronous background task.
    -   **Responsibilities:**
        -   Accept a `task_status_id` as an argument.
        -   Load the `TaskStatus` record to retrieve the list of resource URLs from its `payload`.
        -   Invoke `FhirPushService` to perform the data push.
    -   **Design:**
        - Start smallest-footprint: run GoodJob in-process (async_server) inside Puma; cap job threads at 1–2 to keep the web responsive.
        - Track simple progress via a `TaskStatus` record, updating it after each batch of resources is processed.
        - Optionally support cancel: check a canceled flag between batches and exit cleanly.
        - Migrate when needed (job runs long or impacts web): switch to a tiny external GoodJob worker.
            - Migration steps: reuse the same image and DB; run bin/good_job start with 2–4 threads; disable in-process execution on the web; optionally put the long job on its own queue.
            - After migration: tune threads/batch sizes modestly and checkpoint frequently so the worker can stop and resume mid-process.

### Real-time UI Updates

1.  **Technology:** Updates to the data push job's status will be pushed to the client in real-time using Action Cable and Turbo Streams, which is the idiomatic approach for a modern Hotwire application and is more efficient than polling.
2.  **Implementation:**
    -   A `TaskStatusChannel` will be created for clients to subscribe to.
    -   The `FhirDataPushJob` will broadcast updates to the `TaskStatus` model over this channel after processing batches of resources.
    -   The `load_data.html.erb` view will include a `<%= turbo_stream_from @task_status %>` tag (or similar) to subscribe to the stream.
    -   The `TaskStatus` model will be configured to broadcast changes to itself. Turbo Streams will automatically render a partial (e.g., `_task_status.html.erb`) and push the update to the client. This will replace the need for the `task-status:update` event in `task_status_controller.js`, though the controller will still be useful for client-side interactions like the "Dismiss" button.

### Database Migration

1.  **Modify `task_statuses` table**
    -   A migration will be created to add a `payload` column (`text` or `json` type) to the `task_statuses` table.
    -   This column will store the list of resource URLs that the background job needs to process, decoupling the controller from the job.

---

## 3. Step-by-Step Implementation Guide

### Step 1: Create Migration for `TaskStatus`

1.  Generate a new migration:
    ```bash
    bin/rails g migration AddPayloadToTaskStatuses payload:text
    ```
2.  Run the migration:
    ```bash
    bin/rails db:migrate
    ```

### Step 2: Implement the Services

1.  Create `app/services/sample_data_service.rb`. Implement methods to fetch the manifest, list releases, structure data for views, and fetch individual resource content. Use `Rails.cache` for caching.
2.  Create `app/services/fhir_push_service.rb`. Extract the resource pushing logic from `lib/tasks/fhir_data_pusher.rake` into this service.

### Step 3: Create the Active Job

1.  Create `app/jobs/fhir_data_push_job.rb`.
2.  Implement the `perform` method to load the `TaskStatus` record and call `FhirPushService`.
3.  Set up and configure GoodJob

### Step 4: Refactor `SampleDataController`

1.  Open `app/controllers/sample_data_controller.rb`.
2.  Remove the `load_use_cases` method and all logic related to the local file system and the `sample_data:scrape` task.
3.  Update the `index` and `load_data` actions to use `SampleDataService`. They will now fetch a list of releases and the structured data for the selected release.
4.  Rewrite the `push_data` action to:
    -   Use `SampleDataService` to get the resource URLs based on the selected release/scene.
    -   Create a `TaskStatus` record, storing the list of URLs in the new `payload` field.
    -   Enqueue the `FhirDataPushJob` with the new `task_status.id`.

### Step 5: Update the Views

1.  Modify `app/views/sample_data/index.html.erb` and `app/views/sample_data/load_data.html.erb`.
2.  Add a `<select>` dropdown menu to allow users to choose a sample data release. This should reload the page with a `release_tag` parameter.
3.  Update the forms in `load_data.html.erb` to submit release and scene identifiers instead of local folder paths.
4.  Update links to pass the `release_tag` so the selection persists across pages.

### Step 6: Refactor the Rake Task

1.  Modify `lib/tasks/fhir_data_pusher.rake`.
2.  Change the `fhir:push` task to accept a release tag as an argument.
3.  The task will now use `SampleDataService` to get the list of URLs for that release and then call `FhirPushService` to execute the push. This preserves its command-line utility.

### Step 7: Cleanup

1.  Delete the file `lib/tasks/sample_data_scraper.rake`.
2.  Delete the entire `sample_use_cases/` directory.
    ```bash
    rm lib/tasks/sample_data_scraper.rake
    rm -rf sample_use_cases
    ```

---

## 4. Configuration

The URL for the `manifest.json` file is not a secret and is not expected to change often, so it will be stored in the application configuration.

1.  Open `config/application.rb`.
2.  Add the following line inside the `Application` class:
    ```ruby
    config.x.sample_data.manifest_url = 'https://paciowg.github.io/sample-data-fsh/manifest.json'
    ```
3.  The service can then access this URL via `Rails.configuration.x.sample_data.manifest_url`.
