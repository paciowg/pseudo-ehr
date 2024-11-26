# PSEUDO-EHR

A Rails 7 application styled with Tailwind CSS that interacts with a FHIR server to fetch and display patient information.

**PseudoEHR** is a reference implementation client application for the [PACIO Project](https://pacioproject.org/) use cases. It supports the following PACIO Implementation Guides:

- [**PACIO Advance Directive Interoperability (ADI)**](https://build.fhir.org/ig/HL7/fhir-pacio-adi/branches/master/index.html)
- [**PACIO Personal Functioning and Engagement (PFE)**](https://build.fhir.org/ig/HL7/fhir-pacio-pfe/index.html)
- [**PACIO Transitions of Care (TOC)**](https://paciowg.github.io/transitions-of-care-fsh/index.html)
- [**Standardized Medication Profile (SMP)**](https://build.fhir.org/ig/HL7/smp-ig/index.html)

## Table of Contents

- [Features](#features)
- [Supported FHIR Resources](#supported-fhir-resources)
- [Prerequisites](#prerequisites)
- [Technologies Used](#technologies-used)
- [Installation](#installation)
- [Usage](#usage)
- [Application Structure](#application-structure)
- [Testing](#testing)
- [Common Commands](#common-commands)
- [Contributing](#contributing)
- [License](#license)

## Features

- **FHIR Server Integration**: Connects to FHIR servers to fetch and cache patient details.
- **Patient Display**: Shows a list of patients and individual patient details.
- **Server Authentication**: Handles FHIR servers that require [SMART-on-FHIR App Launch for Symmetric Client Auth](https://build.fhir.org/ig/HL7/smart-app-launch/example-app-launch-symmetric-auth.html#step-2-launch).

## Supported FHIR Resources

The application is able to query (read/search) and display the following FHIR resources:

- **Patient**
- **Organization**
- **Location**
- **PractitionerRole**
- **DocumentReference**
- **Composition**
- **Observation**
- **Condition**
- **ServiceRequest**
- **NutritionOrder**
- **Goal**
- **CareTeam**
- **List**

All searches are performed using the `_include=*` parameter to retrieve and include related resources.

## Prerequisites

- Ruby version 3.1.2 or higher
- Rails 7
- PostgreSQL
- Memcached

## Technologies Used

- **Ruby on Rails 7**: The main web framework.
- **Turbo**: Part of the Hotwire stack used for making real-time page updates without needing JavaScript.
- **Stimulus**: A JavaScript framework that augments HTML with behavior using simple, declarative attributes.
- **Tailwind CSS**: Used for styling the UI.
- **FHIR Integration**: For interacting with FHIR servers, focusing on patient data.
- **PostgreSQL**: The relational database used.
- **Memcached**: For caching data retrieved from the FHIR server.
- **RSpec**: Testing framework for unit and feature tests.

## Installation

Make sure to start PostgreSQL and Memcached before running the server.

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

    >> **Note**: This should only be executed the first time you clone this repository.
                  `rails db:seed` will persist the default servers commonly used in PACIO
                  tracks and this app has been tested against

## Usage

1. **Starting the Server**

    ```bash
      ./bin/dev
    ```

    Open your browser and navigate to `http://localhost:3000`.

2. **Connecting to a FHIR Server**

    - Navigate to the root path.
    - Select a FHIR server from the list of saved servers or enter your FHIR server details and connect.
    - Once connected, you can view a list of patients or see details of a specific patient.

This app has been tested with the following FHIR servers:

| Server Name                                 | Base URL                                             | Tested IGs                      |
|---------------------------------------------|------------------------------------------------------|----------------------------------|
| Michigan Health Information Network (MiHIN) | `https://gw.interop.community/MiHIN/open`            | PFE, SMP, TOC                   |
| MaxMD FHIR Server                           | `https://qa-rr-fhir2.maxmddirect.com`                | ADI                             |

## Application Structure

The Pseudo-EHR application follows the standard Rails structure with a few custom directories:

- **app/**: Contains the core logic of the app including models, views, controllers, and services.
  - **controllers/**: Handles the request-response cycle.
  - **models/**: Contains business logic and data manipulation methods.
  - **views/**: Templates for rendering HTML responses.
  - **services/**: Custom service classes for managing FHIR integration and other core functionalities.
- **config/**: Configuration files for the Rails application, including routes, initializers, and environment settings.
- **db/**: Manages the database schema, migrations, and seeds.
- **lib/**: Contains custom libraries and modules used throughout the app.
- **spec/**: RSpec tests for unit and integration testing.
- **public/**: Static assets and compiled files.

## Testing

  This application uses RSpec for testing. You can find tests in the `spec/` folder, organized by models, controllers, and features.

1. **Running the Test Suite**

    ```bash
      bundle exec rspec
    ```

2. **Factories**

    We use `FactoryBot` gem to mock objects for testing. Check the `spec/factories` directory for defined factories.

## Common Commands

- **Start the app**:

  ```bash
  ./bin/dev
  ```

- **Run RSpec tests**:

   ```bash
  bundle exec rspec
  ```

- **Check for code linting (Rubocop)**:

  ```bash
  bundle exec rubocop
  ```

- **Run database migrations**:

  ```bash
  rails db:migrate
  ```

## Contributing

Please read the [**Contributing to PseudoEHR**](CONTRIBUTING.md) guide and our [**Style Guidelines**](STYLE_GUIDELINES.md).

## License

  This project is licensed under the Apache License. See the `LICENSE` file for details.
