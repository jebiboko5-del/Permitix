# Permitix - Building Permit Smart Contract

A transparent blockchain-based building permit management system built on Stacks using Clarity.

## Overview

Permitix enables transparent issuance, management, and tracking of building permits on-chain. The system provides automated expiry handling, authority management, and comprehensive permit lifecycle tracking.

## Features

- **Permit Issuance**: Authorized authorities can issue building permits with specific durations
- **Expiry Management**: Automatic permit expiry based on block height
- **Authority Control**: Multi-authority system with activation/deactivation controls
- **Permit Transfer**: Transfer permit ownership between principals
- **Renewal System**: Extend permit validity with additional block duration
- **Revocation**: Authority or contract owner can revoke permits
- **Audit Trail**: Complete history tracking for all permit actions
- **Query Functions**: Comprehensive read-only functions for permit status checking

## Core Functions

### Authority Management

```clarity
(add-authority (authority principal) (name "Authority Name"))
(deactivate-authority (authority principal))
```

### Permit Operations

```clarity
(issue-permit 
  (applicant principal)
  (permit-type "residential")
  (property-address "123 Main St") 
  (description "Single family home construction")
  (duration-blocks u1000)
  (fee u500))

(renew-permit (permit-id u1) (additional-blocks u500))
(revoke-permit (permit-id u1) "Safety violations")
(transfer-permit (permit-id u1) (new-applicant principal))
```

### Query Functions

```clarity
(get-permit (permit-id u1))
(is-permit-valid (permit-id u1))
(get-permit-status (permit-id u1))
(get-applicant-permits (applicant principal))
(get-permits-expiring-soon u144)
(get-contract-stats)
```

## Setup

1. Install Clarinet:
```bash
curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-macos-x64.tar.gz | tar xz
```

2. Clone and initialize:
```bash
git clone <repository-url>
cd Permitix
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

## Contract Structure

### Data Maps
- `permits`: Core permit data storage
- `authorities`: Authorized permit issuers
- `permit-history`: Action history tracking
- `applicant-permits`: Per-applicant permit listings

### Error Codes
- `u1000`: Not authorized
- `u1001`: Permit not found  
- `u1002`: Permit expired
- `u1003`: Permit already exists
- `u1004`: Invalid duration
- `u1005`: Permit revoked
- `u1006`: Authority not found

## Usage Examples

### Issue a Permit
```clarity
;; Authority issues a residential permit
(contract-call? .permitix issue-permit 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  "residential"
  "456 Oak Avenue" 
  "Two-story house construction"
  u2000
  u750)
```

### Check Permit Status
```clarity
;; Check if permit is still valid
(contract-call? .permitix is-permit-valid u1)

;; Get detailed permit information
(contract-call? .permitix get-permit u1)
```

### Transfer Permit
```clarity
;; Transfer to new owner
(contract-call? .permitix transfer-permit 
  u1 
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

## Block Height System

The contract uses Stacks block height for time-based operations:
- Permits expire based on block height rather than wall-clock time
- Typical duration: ~144 blocks per day
- Renewal extends expiry by additional blocks

## Security Features

- Contract owner controls for system management
- Authority-based permit issuance restrictions
- Permit ownership verification for transfers
- Comprehensive input validation and error handling
- Immutable audit trail for all permit actions

## Development

Built with Clarity v2 features including:
- Updated `stacks-block-height` function
- Modern error handling patterns
- Efficient data structure utilization
- Comprehensive read-only query functions

For development questions or contributions, see the contract source code for detailed implementation.
