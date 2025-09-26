# Observation Trending and Graphing: Requirements and Development Plan

This document outlines the requirements and a phased development plan for implementing a feature to visualize FHIR Observation data over time.

## 1. Requirements

### Goal
Provide clinicians with the ability to view trends of specific patient observations over time through a graphical interface.

### User Story
As a clinician, when I am viewing a patient's observations, I want to be able to generate a graph for a specific type of observation so that I can easily visualize trends, patterns, and changes over time.

### Functional Requirements
1.  **Graph Generation Trigger**: A "Graph" button will be displayed on the "Single Observations" view when the filtered results meet specific criteria.

2.  **Button Visibility Criteria**: The "Graph" button shall only be visible when all of the following conditions are met for the currently filtered list of observations:
    *   All visible observations share the exact same `code`.
    *   There are at least two visible observations.
    *   Each observation has a status of `final` or `amended`.
    *   Each observation has a valid `effectiveDateTime`.
    *   Each observation has a `valueQuantity`.

3.  **Graph Display**:
    *   Clicking the "Graph" button will open a modal or popover displaying the chart.
    *   The graph will be a line chart plotting the observation's value (Y-axis) against its effective time (X-axis).
    *   The chart must have a clear title, typically derived from the observation's code or description.
    *   The X and Y axes must be clearly labeled (e.g., "Date" and "mg/dL").

4.  **Handling of Component Observations**:
    *   Observations that contain multiple components (e.g., Blood Pressure with Systolic and Diastolic members) must be plotted on a single graph.
    *   Each component will be rendered as a separate series on the chart, distinguished by color and a legend.

---

## 2. Development Plan

The implementation is broken into three phases: Back-end data preparation, Front-end UI for the trigger button, and Front-end graph rendering.

### Phase 1: Back-end - Data Preparation Endpoint

This phase focuses on creating a dedicated API endpoint that formats observation data specifically for consumption by a charting library.

*   **Task 1.1: Create New Route**
    *   **File**: `config/routes.rb`
    *   **Action**: Add a new collection route to the observations resource to handle graph data requests.
    *   **Example**: `get 'graph', on: :collection` resulting in `GET /patients/:patient_id/observations/graph`

*   **Task 1.2: Implement Controller Action**
    *   **File**: `app/controllers/observations_controller.rb`
    *   **Action**: Implement the `graph` action.
    *   **Details**:
        *   The action will accept a comma-separated list of observation IDs from a query parameter (e.g., `?ids=1,2,3`).
        *   It will find the corresponding `Observation` objects from the application's cache.
        *   It will differentiate between single-value observations and collection-based observations (like blood pressure).
        *   The action will return a JSON payload structured for a charting library, including a title, y-axis label, and one or more data series.
        *   A private helper method, `parse_measurement`, will be created to robustly extract a numeric value and unit string from the `measurement` attribute.

### Phase 2: Front-end - Graph Button UI and Logic

This phase involves modifying the existing UI to include the "Graph" button and the client-side logic to control its visibility.

*   **Task 2.1: Enhance Observation Table Data**
    *   **File**: `app/views/observations/_observations_table.html.erb`
    *   **Action**: Add `data-*` attributes to the `<tr>` for each observation row to expose its `id`, `code`, `status`, `effective-date-time`, and presence of a `valueQuantity` (e.g., `data-has-value-quantity="true"`) to the Stimulus controller.

*   **Task 2.2: Add Graph Button to View**
    *   **File**: `app/views/observations/index.html.erb`
    *   **Action**: Add a `<button>` element for "Graph" near the search filter input. It will be hidden by default and given a `data-filter-target="graphButton"`.

*   **Task 2.3: Update Filter Controller**
    *   **File**: `app/javascript/controllers/filter_controller.js`
    *   **Action**:
        *   Add `graphButton` to the `static targets` array.
        *   Create a new private method, `_updateGraphButtonState()`, which will be called at the end of the existing `filter()` method.
        *   This new method will check all visible observation rows against the visibility criteria (count, same code, status, effective time, and presence of `valueQuantity`).
        *   If criteria are met, it will make the `graphButton` visible and store the IDs of the valid observations in a `data-ids` attribute on the button. Otherwise, it will ensure the button is hidden.

### Phase 3: Front-end - Graph Rendering

This phase focuses on creating the client-side components to fetch the graph data and render the chart in a modal.

*   **Task 3.1: Install Charting Library**
    *   **Action**: Select and install a JavaScript charting library. ApexCharts.js is a strong candidate as it is powerful and works well with Stimulus and importmaps.
    *   **Command**: `bin/importmap pin apexcharts`

*   **Task 3.2: Add Modal and Controller Hooks**
    *   **File**: `app/views/observations/index.html.erb`
    *   **Action**:
        *   Add the HTML structure for a generic modal that will contain the chart.
        *   Add a `data-controller="graph"` attribute to a wrapping element.
        *   Connect the "Graph" button to the new controller via a `data-action="click->graph#render"`.

*   **Task 3.3: Create Graph Stimulus Controller**
    *   **File**: `app/javascript/controllers/graph_controller.js` (New File)
    *   **Action**:
        *   Create a new Stimulus controller with `modal` and `chart` targets.
        *   Implement the `render(event)` action, which is triggered by the button click.
        *   Inside `render`, it will:
            1.  Read the observation IDs from the `data-ids` attribute of the button that triggered the event.
            2.  Fetch the formatted data from the `/.../observations/graph` endpoint.
            3.  On a successful response, use the chosen charting library to instantiate and render the graph inside the `chartTarget`.
            4.  Display the `modalTarget` to the user.

---

## 3. Considerations for Iterative Development

### Short-Term
*   **Error Handling**: The back-end endpoint and front-end fetch logic must gracefully handle errors, such as observations not being found or network failures.
*   **Unit Consistency**: The initial implementation will assume all observations being graphed share the same unit. The Y-axis label will be derived from the first observation in the set.
*   **Performance**: The current approach of loading from the in-memory cache (`Observation.find`) is sufficient for the expected data volume.

### Long-Term / Future Enhancements
*   **Non-numeric Values**: For observations that have a `valueCodeableConcept` certain code sets (e.g., NOMS Functional Communication Measures scoring) will be graphed.
*   **Unit Conversion**: For observation types that may be recorded in different but compatible units (e.g., kg vs. lbs), a future iteration could add on-the-fly unit conversion.
*   **Interactive Charts**: Enhance charts with features like tooltips on data points, zoom, and pan.
*   **Date Range Filters**: Allow users to filter the data for the graph by a specific date range.
*   **Overlaying Multiple Observation Types**: Explore options for plotting different observation types on the same timeline, potentially using multiple Y-axes.
*   **Performance at Scale**: If patients have thousands of data points for a single observation code, the backend may need to be optimized to aggregate data or stream it rather than returning a single large JSON payload.
