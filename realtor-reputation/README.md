# Realtor Reputation System on Stacks

This project implements an on-chain reputation system for real estate agents built on the Stacks blockchain. The system provides a transparent and tamper-proof way to track realtor performance based on verified transactions and client reviews.

## Project Overview

**Name:** Reputation System for Realtors
**Objective:** Build an on-chain reputation score for real estate agents based on verified transactions and reviews.
**Target Blockchain:** Stacks (Bitcoin Layer)

## Architecture

The system is composed of four main smart contracts:

1. **Realtor Registry (`realtor-registry.clar`)**: Manages realtor registration and profile information
2. **Transaction Registry (`transaction-registry.clar`)**: Records and verifies real estate transactions
3. **Review Registry (`review-registry.clar`)**: Manages client reviews and ratings for realtors
4. **Reputation System (`realtor-reputation.clar`)**: Calculates reputation scores based on transaction history and reviews

## Key Features

- **Realtor Registration**: Realtors can register with their license number and company information
- **Transaction Verification**: Property transactions can be recorded and verified
- **Client Reviews**: Clients can leave reviews and ratings for realtors
- **Reputation Scoring**: Comprehensive scoring system based on transaction volume and customer satisfaction
- **Transparent Metrics**: All data is publicly viewable on the blockchain

## Reputation Score Calculation

The reputation score is calculated using a weighted formula:
- 60% based on verified transaction history
- 40% based on client reviews and ratings

The final score is a number between 0-100, with higher scores indicating greater reputation.

## Development Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development environment
- [Node.js](https://nodejs.org/) - For running tests
- Git

### Getting Started

1. Clone the repository:
```bash
git clone https://github.com/yourusername/realtor-reputation.git
cd realtor-reputation
```

2. Initialize the Clarinet project:
```bash
clarinet integrate
```

3. Run tests:
```bash
clarinet test
```

## Contract Interfaces

### Realtor Registry

```clarity
(define-public (register-realtor (name (string-utf8 100)) (license-number (string-utf8 50)) (brokerage (string-utf8 100)) (profile-uri (optional (string-utf8 256)))))
(define-public (update-profile (name (string-utf8 100)) (brokerage (string-utf8 100)) (profile-uri (optional (string-utf8 256)))))
(define-read-only (get-realtor (realtor principal)))
```

### Transaction Registry

```clarity
(define-public (register-transaction (transaction-id (string-utf8 64)) (property-address (string-utf8 256)) (transaction-type (string-utf8 20)) (transaction-amount uint) (transaction-date uint)))
(define-public (verify-transaction (transaction-id (string-utf8 64))))
(define-read-only (get-transaction (transaction-id (string-utf8 64))))
```

### Review Registry

```clarity
(define-public (submit-review (realtor principal) (rating uint) (review-text (string-utf8 500)) (transaction-id (optional (string-utf8 64)))))
(define-read-only (get-review (review-id (string-utf8 64))))
(define-read-only (get-average-rating (realtor principal)))
```

### Reputation System

```clarity
(define-public (calculate-reputation (realtor principal)))
(define-read-only (get-reputation (realtor principal)))
(define-read-only (has-minimum-reputation (realtor principal) (min-score uint)))
```

## License

MIT

## Contributors

- [Your Name]
