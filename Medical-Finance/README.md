# Medical Billing Automation Smart Contract

## Overview

The Medical Billing Automation Smart Contract is a comprehensive blockchain-based solution designed to automate and streamline medical billing processes. Built on the Stacks blockchain using Clarity, this contract provides secure, transparent, and efficient management of medical bills, payments, and related healthcare transactions.

## Features

### Core Functionality
- **Provider Registration**: Healthcare providers can register with license verification
- **Patient Management**: Secure patient registration and information management
- **Bill Creation**: Automated medical bill generation with detailed service information
- **Payment Processing**: Secure payment handling with multiple payment methods
- **Insurance Integration**: Support for insurance providers and claims processing
- **Dispute Resolution**: Built-in dispute management system
- **Earnings Tracking**: Real-time provider earnings calculation

### Security Features
- **Input Validation**: Comprehensive validation of all user inputs
- **Authorization Controls**: Role-based access control for different user types
- **Emergency Functions**: Administrative controls for emergency situations
- **Audit Trail**: Complete transaction history and tracking

## Contract Architecture

### Data Structures

#### Medical Providers
```clarity
{
    name: string-ascii 100,
    license-number: string-ascii 50,
    authorization-level: uint,
    is-active: bool,
    registration-block: uint
}
```

#### Patients
```clarity
{
    name: string-ascii 100,
    patient-id: string-ascii 50,
    insurance-provider: optional principal,
    emergency-contact: string-ascii 100,
    is-active: bool,
    registration-block: uint
}
```

#### Medical Bills
```clarity
{
    bill-id: uint,
    provider: principal,
    patient: principal,
    amount: uint,
    service-date: uint,
    due-date: uint,
    status: uint,
    description: string-ascii 500,
    diagnosis-code: string-ascii 20,
    treatment-code: string-ascii 20,
    insurance-claim-id: optional string-ascii 50,
    discount-applied: uint,
    created-block: uint,
    paid-block: optional uint
}
```

## Constants and Error Codes

### Bill Status Constants
- `BILL-STATUS-PENDING`: 1
- `BILL-STATUS-PAID`: 2
- `BILL-STATUS-OVERDUE`: 3
- `BILL-STATUS-DISPUTED`: 4
- `BILL-STATUS-CANCELLED`: 5

### Provider Authorization Levels
- `PROVIDER-LEVEL-BASIC`: 1
- `PROVIDER-LEVEL-PREMIUM`: 2
- `PROVIDER-LEVEL-ENTERPRISE`: 3

### Error Codes
- `ERR-OWNER-ONLY`: 100 - Function restricted to contract owner
- `ERR-NOT-FOUND`: 101 - Requested resource not found
- `ERR-ALREADY-EXISTS`: 102 - Resource already exists
- `ERR-INVALID-AMOUNT`: 103 - Invalid amount provided
- `ERR-UNAUTHORIZED`: 104 - Unauthorized access attempt
- `ERR-BILL-ALREADY-PAID`: 105 - Bill has already been paid
- `ERR-INSUFFICIENT-FUNDS`: 106 - Insufficient funds for transaction
- `ERR-INVALID-STATUS`: 107 - Invalid status provided
- `ERR-EXPIRED-BILL`: 108 - Bill has expired
- `ERR-INVALID-DISCOUNT`: 109 - Invalid discount percentage
- `ERR-PROVIDER-NOT-AUTHORIZED`: 110 - Provider not authorized
- `ERR-INVALID-INPUT`: 111 - Invalid input provided

## Public Functions

### Administrative Functions

#### set-contract-owner
```clarity
(set-contract-owner (new-owner principal))
```
Updates the contract owner. Only callable by current owner.

#### update-platform-fee
```clarity
(update-platform-fee (new-fee-percentage uint))
```
Updates the platform fee percentage (max 10%). Only callable by owner.

#### update-late-fee
```clarity
(update-late-fee (new-late-fee-percentage uint))
```
Updates the late fee percentage (max 20%). Only callable by owner.

### Provider Functions

#### register-provider
```clarity
(register-provider (name string-ascii) (license-number string-ascii) (authorization-level uint))
```
Registers a new healthcare provider with license verification.

#### update-provider-status
```clarity
(update-provider-status (provider principal) (is-active bool))
```
Updates provider active status. Only callable by owner.

### Patient Functions

#### register-patient
```clarity
(register-patient (name string-ascii) (patient-id string-ascii) (insurance-provider optional) (emergency-contact string-ascii))
```
Registers a new patient in the system.

#### update-patient-insurance
```clarity
(update-patient-insurance (insurance-provider optional))
```
Updates patient's insurance provider information.

### Billing Functions

#### create-bill
```clarity
(create-bill (patient principal) (amount uint) (service-date uint) (due-date uint) (description string-ascii) (diagnosis-code string-ascii) (treatment-code string-ascii))
```
Creates a new medical bill. Only callable by authorized providers.

#### apply-discount
```clarity
(apply-discount (bill-id uint) (discount-percentage uint))
```
Applies a discount to an existing bill. Only callable by the bill's provider.

#### pay-bill
```clarity
(pay-bill (bill-id uint) (payment-method string-ascii) (transaction-id string-ascii))
```
Processes payment for a medical bill. Callable by patient or provider.

### Insurance Functions

#### register-insurance-provider
```clarity
(register-insurance-provider (name string-ascii) (coverage-percentage uint) (max-coverage uint) (authorization-codes list))
```
Registers an insurance provider. Only callable by owner.

#### process-insurance-claim
```clarity
(process-insurance-claim (bill-id uint) (claim-id string-ascii))
```
Processes an insurance claim for a bill. Callable by provider or insurance company.

### Dispute Functions

#### create-dispute
```clarity
(create-dispute (bill-id uint) (reason string-ascii))
```
Creates a dispute for a bill. Callable by patient or provider.

#### resolve-dispute
```clarity
(resolve-dispute (dispute-id uint) (resolution string-ascii))
```
Resolves a dispute. Only callable by owner.

### Emergency Functions

#### emergency-cancel-bill
```clarity
(emergency-cancel-bill (bill-id uint))
```
Cancels a bill in emergency situations. Only callable by owner.

#### emergency-pause-provider
```clarity
(emergency-pause-provider (provider principal))
```
Pauses a provider's access. Only callable by owner.

## Read-Only Functions

### Data Retrieval

#### get-bill
```clarity
(get-bill (bill-id uint))
```
Retrieves bill information by ID.

#### get-provider
```clarity
(get-provider (provider principal))
```
Retrieves provider information.

#### get-patient
```clarity
(get-patient (patient principal))
```
Retrieves patient information.

#### get-patient-bills
```clarity
(get-patient-bills (patient principal))
```
Retrieves list of bills for a patient.

#### get-provider-earnings
```clarity
(get-provider-earnings (provider principal))
```
Retrieves total earnings for a provider.

#### calculate-bill-amount
```clarity
(calculate-bill-amount (bill-id uint))
```
Calculates final amount for a bill including discounts and late fees.

#### get-platform-stats
```clarity
(get-platform-stats)
```
Retrieves platform statistics including total bills and fees.

## Deployment

### Prerequisites
- Stacks blockchain development environment
- Clarity CLI tools
- Valid Stacks testnet/mainnet account

### Deployment Steps

1. **Compile Contract**
   ```bash
   clarinet check
   ```

2. **Run Tests**
   ```bash
   clarinet test
   ```

3. **Deploy to Testnet**
   ```bash
   clarinet deploy --testnet
   ```

4. **Deploy to Mainnet**
   ```bash
   clarinet deploy --mainnet
   ```

## Usage Examples

### Register as Healthcare Provider
```clarity
(contract-call? .medical-billing register-provider 
    "Dr. Smith Medical Center" 
    "MD123456" 
    u2)
```

### Register as Patient
```clarity
(contract-call? .medical-billing register-patient 
    "John Doe" 
    "PT789012" 
    (some 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7) 
    "Emergency Contact: Jane Doe")
```

### Create Medical Bill
```clarity
(contract-call? .medical-billing create-bill 
    'SP1H1733V5MZ3SZ9XRW9FKYAHJ4NXMKVGR4DZ9M0F 
    u50000 
    u1000 
    u2000 
    "Annual checkup and blood work" 
    "Z00.00" 
    "99213")
```

### Pay Bill
```clarity
(contract-call? .medical-billing pay-bill 
    u1 
    "Credit Card" 
    "TXN123456789")
```

## Security Considerations

### Input Validation
- All user inputs are validated for type, length, and content
- Principal addresses are verified for validity
- Numeric values are checked for reasonable ranges
- String inputs are validated for non-empty content

### Access Control
- Role-based permissions for different user types
- Owner-only functions for administrative tasks
- Provider authorization checks for bill creation
- Patient verification for bill payments

### Data Integrity
- Immutable transaction records
- Complete audit trail for all operations
- Dispute resolution mechanism
- Emergency override capabilities

## Fee Structure

### Platform Fees
- Default platform fee: 2.5% of bill amount
- Configurable by contract owner (max 10%)

### Late Fees
- Default late fee: 5% of bill amount
- Applied to overdue bills automatically
- Configurable by contract owner (max 20%)

## Integration Guidelines

### Frontend Integration
- Use Stacks.js library for contract interactions
- Implement proper error handling for all contract calls
- Validate user inputs before sending transactions
- Provide clear feedback for transaction status

### Backend Integration
- Monitor contract events for real-time updates
- Implement automated processes for overdue bill management
- Set up insurance claim processing workflows
- Create reporting dashboards for providers and administrators

## Testing

### Unit Tests
- Input validation testing
- Authorization control verification
- Business logic validation
- Error handling verification

### Integration Tests
- End-to-end workflow testing
- Multi-user scenario testing
- Payment processing verification
- Dispute resolution testing

## Support and Maintenance

### Contract Updates
- Contract is immutable once deployed
- New features require new contract deployment
- Migration strategies for data preservation
- Backward compatibility considerations

### Monitoring
- Transaction monitoring for security
- Performance metrics tracking
- Error rate monitoring
- User activity analytics