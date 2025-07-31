# PSEUDO-EHR

A Rails 7 application styled with Tailwind CSS that interacts with a FHIR server to fetch and display patient information.

**PseudoEHR** is a reference implementation client application for the [PACIO Project](https://pacioproject.org/) use cases. It supports the following PACIO Implementation Guides:

* [**PACIO Advance Directive Interoperability (ADI)**](https://build.fhir.org/ig/HL7/fhir-pacio-adi/branches/master/index.html)
* [**PACIO Personal Functioning and Engagement (PFE)**](https://build.fhir.org/ig/HL7/fhir-pacio-pfe/index.html)
* [**PACIO Transitions of Care (TOC)**](https://paciowg.github.io/transitions-of-care-fsh/index.html)
* [**Standardized Medication Profile (SMP)**](https://build.fhir.org/ig/HL7/smp-ig/index.html)

## Table of Contents

* [Features](#features)
* [Supported FHIR Resources](#supported-fhir-resources)
* [Prerequisites](#prerequisites)
* [Technologies Used](#technologies-used)
* [Installation](#installation)
* [Usage](#usage)
* [Application Structure](#application-structure)
* [Testing](#testing)
* [Common Commands](#common-commands)
* [Contributing](#contributing)
* [License](#license)

## Features

* **FHIR Server Integration**: Connects to FHIR servers to fetch and cache patient details.
* **Patient Display**: Shows a list of patients and individual patient details.
* **Server Authentication**: Handles FHIR servers that require [SMART-on-FHIR App Launch for Symmetric Client Auth](https://build.fhir.org/ig/HL7/smart-app-launch/example-app-launch-symmetric-auth.html#step-2-launch).
* **Sample Data Management**: Browse and view sample FHIR resources organized by use case and scene, and load them into FHIR servers.
* **QuestionnaireResponse Transformation**: Convert QuestionnaireResponse into PFE Observation Bundles.

## Supported FHIR Resources

The application is able to query (read/search) and display the following FHIR resources:

* **Patient**
* **Organization**
* **Location**
* **PractitionerRole**
* **DocumentReference**
* **Composition**
* **Observation**
* **Condition**
* **ServiceRequest**
* **NutritionOrder**
* **Goal**
* **CareTeam**
* **List**

All searches are performed using the `_include=*` parameter to retrieve and include related resources.

## Prerequisites

* Ruby version 3.1.2 or higher
* Rails 7
* PostgreSQL

## Technologies Used

* **Ruby on Rails 7**: The main web framework.
* **Turbo**: Part of the Hotwire stack used for making real-time page updates without needing JavaScript.
* **Stimulus**: A JavaScript framework that augments HTML with behavior using simple, declarative attributes.
* **Tailwind CSS**: Used for styling the UI.
* **FHIR Integration**: For interacting with FHIR servers, focusing on patient data.
* **PostgreSQL**: The relational database used.
* **RSpec**: Testing framework for unit and feature tests.

## Installation

Make sure to start PostgreSQL before running the server.

1. **Clone the Repository**

   ```bash
    git clone https://github.com/paciowg/pseudo-ehr.git
    cd pseudo-ehr
   ```

2. **Install Dependencies**

   ```bash
    yarn install
    bundle install
   ```

3. **Database Setup**

   ```bash
     rails db:create
     rails db:migrate
     rails db:seed
   ```

   > > **Note**: This should only be executed the first time you clone this repository.
   > > `rails db:seed` will persist the default servers commonly used in PACIO
   > > tracks and this app has been tested against


## Usage

1. **Starting the Server**

   ```bash
     ./bin/dev
   ```

   Open your browser and navigate to `http://localhost:3000`.

2. **Connecting to a FHIR Server**

   * Navigate to the root path.
   * Select a FHIR server from the list of saved servers or enter your FHIR server details and connect.
   * Once connected, you can view a list of patients or see details of a specific patient.

This app has been tested with the following FHIR servers:

| Server Name                                 | Base URL                                  | Tested IGs    |
| ------------------------------------------- | ----------------------------------------- | ------------- |
| Michigan Health Information Network (MiHIN) | `https://gw.interop.community/MiHIN/open` | PFE, SMP, TOC |
| MaxMD FHIR Server                           | `https://qa-rr-fhir2.maxmddirect.com`     | ADI           |

## Application Structure

The Pseudo-EHR application follows the standard Rails structure with a few custom directories:

* **app/**: Contains the core logic of the app including models, views, controllers, and services.

  * **controllers/**: Handles the request-response cycle.
  * **models/**: Contains business logic and data manipulation methods.
  * **views/**: Templates for rendering HTML responses.
  * **services/**: Custom service classes for managing FHIR integration and other core functionalities.
* **config/**: Configuration files for the Rails application, including routes, initializers, and environment settings.
* **db/**: Manages the database schema, migrations, and seeds.
* **lib/**: Contains custom libraries and modules used throughout the app.
* **spec/**: RSpec tests for unit and integration testing.
* **public/**: Static assets and compiled files.

## Testing

This application uses RSpec for testing. You can find tests in the `spec/` folder, organized by models, controllers, and features.

1. **Running the Test Suite**

   ```bash
     bundle exec rspec
   ```

2. **Factories**

   We use `FactoryBot` gem to mock objects for testing. Check the `spec/factories` directory for defined factories.

## Common Commands

* **Start the app**:

  ```bash
  ./bin/dev
  ```

* **Run RSpec tests**:

  ```bash
  bundle exec rspec
  ```

* **Check for code linting (Rubocop)**:

  ```bash
  bundle exec rubocop
  ```

* **Run database migrations**:

  ```bash
  rails db:migrate
  ```

* **Scrape FHIR sample data**:

  ```bash
  bundle exec rake sample_data:scrape
  ```

  This rake task scrapes and downloads Betsy Smith-Johnson sample FHIR resources from the [PACIO sample data depo FSH](https://build.fhir.org/ig/paciowg/sample-data-fsh/pacio_persona_betsySmithJohnson.html). It organizes the JSON files by scene and resource type in the `sample_use_cases` folder. The task is automatically run when loading sample data through the application, with a 5-hour cache to prevent excessive scraping operations.

* **Push FHIR resources to a server**:

  ```bash
  bundle exec rake fhir:push[server_url,folder_path]
  ```

  This rake task pushes FHIR resources to a FHIR server in the correct dependency order. It takes two arguments:

  * `server_url`: The base URL of the FHIR server
  * `folder_path`: The path to the folder containing the FHIR resources to push

  Example:

  ```bash
  bundle exec rake fhir:push[http://hapi.fhir.org/baseR4,sample_use_cases/betsy_smith_johnson_stroke_use_case_pacio_sample_data_depot_v0_1_0]
  ```

  The task analyzes resource dependencies to ensure referenced resources are pushed before the resources that reference them. It generates a detailed log report in the project's `log/fhir_push_logs` directory that includes information about successful uploads and any errors encountered, including error messages extracted from FHIR OperationOutcome resources.

* **Transform QuestionnaireResponses to Observations**:

  ```bash
  bundle exec rake "fhir:fetch_and_transform_qr[server_url,patient_id]"
  ```

  Fetches all QuestionnaireResponses for a given patient from the specified FHIR server, converts them into PFE Observation Bundles, and stores them in `tmp/fhir_bundles/`. Semantic matching is used to infer domain categories.

* **Submit transformed bundles to a FHIR server**:

  ```bash
  bundle exec rake "fhir:submit_bundles[server_url]"
  ```

  Submits all bundles in `tmp/fhir_bundles/` as FHIR transaction bundles to the specified server. Logs outcomes for each submission.

* **Extract conformance requirements from a capability statement**:

  ```bash
  bundle exec rake "capability_statement:extract_requirements[path/to/capability_statement.json]"
  ```

  Extracts conformance requirements from a FHIR capability statement JSON file and writes them to an Excel file in the `./requirements` directory. The Excel file is named based on the capability statement title (in snake case) and includes columns for URL, requirement, conformance level (SHALL, SHOULD, MAY), and actor (server/client).

  Note: The generated requirements file should be reviewed and corrected by a human to ensure accuracy, as the automated extraction may not capture all nuances of the capability statement.

* **Generate PFE domain mapping**:

  ```bash
  bundle exec rake pfe:generate_domain_mapping
  ```

  Downloads the PFE domain CodeSystem and saves them locally in `config/pfe_domain_mapping.yml` for use in domain code detection.

## Contributing

Please read the [**Contributing to PseudoEHR**](CONTRIBUTING.md) guide and our [**Style Guidelines**](STYLE_GUIDELINES.md).

## License

This project is licensed under the Apache License. See the `LICENSE` file for details.
