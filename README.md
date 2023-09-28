# PSEUDO-EHR

A Rails 7 application styled with Tailwind CSS that interacts with a FHIR server to fetch and display patient information.

**PseudoEHR** is a reference implementation client application for the [PACIO Project](https://pacioproject.org/) use cases.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Features

- **FHIR Server Integration**: Connects to FHIR servers to fetch and cache patient details.
- **Patient Display**: Shows a list of patients and individual patient details.
- **Server Authentication**: Handles FHIR servers that require [SMART-on-FHIR App Launch for Symmetric Client Auth](https://build.fhir.org/ig/HL7/smart-app-launch/example-app-launch-symmetric-auth.html#step-2-launch).

## Prerequisites

- Ruby version 2.7.5 or higher
- Rails 7
- PostgreSQL
- Memcached

Make sure to start PostgreSQL and Memcached before running the server.

## Installation

1. **Clone the Repository**

   ```bash
    git clone https://github.com/paciowg/pseudo-ehr.git
    cd pseudo-ehr
   ```

2. **Install Dependencies**

    ```bash
     bundle install
    ```

3. **Database Setup**

    ```bash
      rails db:create
      rails db:migrate
    ```

    >> **Note**: This should only be executed the first time you clone this repository.

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

## Testing

  This application uses RSpec for testing.

1. **Running the Test Suite**

    ```bash
      bundle exec rspec
    ```

2. **Factories**

    We use `FactoryBot` gem to mock objects for testing. Check the `spec/factories` directory for defined factories.

## Contributing

Please read the [**Contributing to PseudoEHR**](CONTRIBUTING.md) guide and our [**Style Guidelines**](STYLE_GUIDELINES.md).

## License

  This project is licensed under the Apache License. See the `LICENSE` file for details.
