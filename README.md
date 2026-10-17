# Directory Account Auditor

Directory Account Auditor is a Powershell-based auditing framework for identifying incomplete, malformed, or inconsistent directory account data.

## Purpose

This project demonstrates:

- Directory account auditing
- Attribute normalization
- Required-attribute validation
- Malformed-value detection
- Cross-attribute consistency checking
- Structured reporting
- Seperation of business logic from infrastructure dependencies 
- Automated testing with Pester
- Source-controlled Powershell development 

## Project Structure

- `src/` - Application source code
- `tests/` - Pester automated tests
- `examples/` - Synthetic example data
- `docs/` - Documentation

## Data Safety 

All users, organizations, identifiers, locations, domains, and directory data contained in this repository are fictional and intended solely for demonstration and testing.

This repository does not contain production directory data or proprietary organizational configuration.

## Requirements

- Powershell 7+
- Pester
- Appropriate directory-management module when querying a live directory 

## Status

Early development / portfolio project.
