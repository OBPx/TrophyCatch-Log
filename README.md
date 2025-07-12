# Trophy Catch NFT Contract

A Clarity smart contract for minting and managing non-fungible tokens (NFTs) that represent verified trophy fishing catches. This contract creates an immutable, on-chain record of significant fishing achievements, verified by certified fishing guides.

## Overview

The Trophy Catch NFT contract allows certified fishing guides to mint NFTs representing trophy catches for anglers. Each NFT contains comprehensive metadata about the catch, including species, weight, length, location, and verification details. The contract ensures data integrity through guide certification and comprehensive input validation.

## Features

- **Certified Guide System**: Only certified guides can mint trophy NFTs
- **Comprehensive Metadata**: Each NFT stores detailed catch information
- **Immutable Records**: Trophy data cannot be altered once minted (except angler notes)
- **Transfer Support**: NFTs can be transferred between principals
- **Efficient Querying**: Optimized data structures for balance and metadata retrieval
- **Input Validation**: Comprehensive validation for all user inputs

## Contract Architecture

### Core Components

1. **NFT Definition**: `trophy-catch` non-fungible token
2. **Guide Certification**: System for authorizing guides to mint NFTs
3. **Metadata Storage**: Comprehensive catch data storage
4. **Owner Tracking**: Efficient NFT count management per owner

### Data Structures

```clarity
;; Trophy metadata structure
{
  species: (string-ascii 32),
  weight-grams: uint,
  length-cm: uint,
  catch-location: (string-ascii 64),
  angler-note: (string-utf8 256),
  media-url: (string-ascii 128),
  verified-guide: principal
}
```

## Functions

### Administrative Functions

#### `certify-guide`
Certifies a new fishing guide to mint trophy NFTs.
- **Access**: Contract owner only
- **Parameters**: `guide` (principal)
- **Returns**: `(response bool uint)`

#### `decertify-guide`
Removes a guide's certification.
- **Access**: Contract owner only
- **Parameters**: `guide` (principal)
- **Returns**: `(response bool uint)`

### Public Functions

#### `mint-trophy`
Mints a new trophy catch NFT.
- **Access**: Certified guides only
- **Parameters**:
  - `angler` (principal): Recipient of the NFT
  - `species` (string-ascii 32): Fish species
  - `weight-grams` (uint): Weight in grams
  - `length-cm` (uint): Length in centimeters
  - `catch-location` (string-ascii 64): Location description
  - `angler-note` (string-utf8 256): Personal note from angler
  - `media-url` (string-ascii 128): URL to catch media
- **Returns**: `(response uint uint)` - Token ID on success

#### `transfer-trophy`
Transfers an NFT to another principal.
- **Access**: NFT owner only
- **Parameters**:
  - `token-id` (uint): NFT identifier
  - `sender` (principal): Current owner
  - `recipient` (principal): New owner
- **Returns**: `(response bool uint)`

#### `update-angler-note`
Updates the personal note on a trophy NFT.
- **Access**: NFT owner only
- **Parameters**:
  - `token-id` (uint): NFT identifier
  - `new-note` (string-utf8 256): Updated note
- **Returns**: `(response bool uint)`

### Read-Only Functions

#### `get-trophy-details`
Returns comprehensive metadata for a trophy NFT.
- **Parameters**: `token-id` (uint)
- **Returns**: `(optional {metadata-structure})`

#### `get-owner`
Returns the owner of a specific NFT.
- **Parameters**: `token-id` (uint)
- **Returns**: `(optional principal)`

#### `is-guide-certified`
Checks if a guide is certified.
- **Parameters**: `guide` (principal)
- **Returns**: `bool`

#### `get-balance`
Returns the number of NFTs owned by a principal.
- **Parameters**: `owner` (principal)
- **Returns**: `uint`

#### `get-last-token-id`
Returns the total number of minted NFTs.
- **Returns**: `uint`

#### `get-contract-owner`
Returns the contract owner principal.
- **Returns**: `principal`

#### `get-validation-limits`
Returns the validation limits for trophy data.
- **Returns**: `{max-weight-grams: uint, min-weight-grams: uint, max-length-cm: uint, min-length-cm: uint}`

## Validation Rules

### Weight Validation
- **Minimum**: 1 gram
- **Maximum**: 1,000,000 grams (1000 kg)

### Length Validation
- **Minimum**: 1 cm
- **Maximum**: 1,000 cm (10 meters)

### String Validation
- All string fields must be non-empty
- Angler notes are limited to 256 UTF-8 characters
- Species names are limited to 32 ASCII characters
- Locations are limited to 64 ASCII characters
- Media URLs are limited to 128 ASCII characters

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 101 | `ERR_NOT_AUTHORIZED` | Caller not authorized for this action |
| 102 | `ERR_GUIDE_NOT_CERTIFIED` | Guide is not certified |
| 103 | `ERR_ALREADY_CERTIFIED` | Guide is already certified |
| 104 | `ERR_MINTING_FAILED` | NFT minting operation failed |
| 105 | `ERR_NFT_NOT_FOUND` | NFT does not exist |
| 106 | `ERR_SENDER_NOT_OWNER` | Caller is not the NFT owner |
| 107 | `ERR_METADATA_LOCKED` | Metadata cannot be modified |
| 108 | `ERR_METADATA_INVALID` | Invalid metadata provided |
| 109 | `ERR_INVALID_WEIGHT` | Weight outside valid range |
| 110 | `ERR_INVALID_LENGTH` | Length outside valid range |
| 111 | `ERR_INVALID_RECIPIENT` | Invalid recipient principal |

## Usage Examples

### Certifying a Guide

```clarity
;; Contract owner certifies a guide
(contract-call? .trophy-catch-nft certify-guide 'SP1234567890ABCDEF)
```

### Minting a Trophy

```clarity
;; Certified guide mints a trophy catch NFT
(contract-call? .trophy-catch-nft mint-trophy 
  'SP1ANGLER123456789  ;; angler principal
  "Largemouth Bass"    ;; species
  u2500               ;; weight in grams (2.5 kg)
  u45                 ;; length in cm
  "Lake Superior"     ;; location
  u"My biggest catch ever!" ;; angler note
  "https://example.com/photo.jpg" ;; media URL
)
```

### Transferring an NFT

```clarity
;; NFT owner transfers to another principal
(contract-call? .trophy-catch-nft transfer-trophy 
  u1                    ;; token ID
  'SP1ANGLER123456789   ;; sender (current owner)
  'SP2NEWOWNER987654321 ;; recipient
)
```

### Querying Trophy Details

```clarity
;; Get comprehensive trophy information
(contract-call? .trophy-catch-nft get-trophy-details u1)

;; Check NFT owner
(contract-call? .trophy-catch-nft get-owner u1)

;; Get angler's NFT count
(contract-call? .trophy-catch-nft get-balance 'SP1ANGLER123456789)
```

## Development

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v0.31.1 or higher
- [Stacks CLI](https://docs.stacks.co/docs/cli)

### Setup

1. Clone the repository
2. Install Clarinet
3. Run contract checks:

```bash
clarinet check
```

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy
```

## Security Considerations

1. **Access Control**: Only certified guides can mint NFTs
2. **Data Integrity**: Most metadata is immutable after minting
3. **Input Validation**: All inputs are validated before processing
4. **Principal Verification**: Prevents invalid recipient assignments
5. **Owner Verification**: Ensures only NFT owners can transfer or update notes

## Gas Optimization

The contract is optimized for gas efficiency through:
- Efficient data structures for owner counting
- Minimal redundant operations
- Optimized validation logic
- Single-pass validation for all inputs

## License

This contract is provided under the MIT License. See LICENSE file for details.

## Contributing

Contributions are welcome! Please ensure all code passes Clarinet checks and includes appropriate tests.

## Support

For questions or issues, please open an issue in the project repository.