# FishCardV1 Contract Documentation

## Overview

FishCardV1 is a Non-Fungible Token (NFT) contract built on the Flow blockchain that represents verified digital catch records in the DerbyFish ecosystem. Each FishCard NFT encapsulates comprehensive data about a fish catch, including media evidence, verification details, and both public and private metadata. The contract implements Flow's standard NFT interfaces while providing specialized functionality for fishing tournament and derby applications.

## Architecture

### Core Components

**Contract Structure**: FishCardV1 extends Flow's `NonFungibleToken` interface and implements `ViewResolver` for metadata display. The contract maintains a total supply counter and provides three primary resources: `NFT`, `Collection`, and `Minter`.

**Storage Architecture**: The contract uses four distinct storage paths:
- `/storage/fishCardCollection` - User NFT collections
- `/public/fishCardCollection` - Public collection access
- `/storage/fishCardMinter` - Minting authorization
- `/storage/fishCardAdmin` - Administrative functions

### Data Structures

#### Submission Standards
The contract supports three verification methods through the `SubmissionStandard` enum:
- **BHRV**: Bump, Hero, Release - Traditional catch documentation
- **FISHSCAN**: Livestream with 3D gyro scan - Advanced verification with 3x3 grid photography
- **BANANNASCAN**: Test verification method for development

#### Media Management
Each FishCard contains a `MediaItem` array with Flow decentralized storage:
- **MIME type**: Content format specification
- **Flow Storage Path**: Decentralized storage location on Flow network
- **Hash**: Content integrity verification
- **Algorithm**: Hashing method used
- **Storage Size**: Size of media in bytes
- **Required FLOW Stake**: FLOW tokens that must be staked (0.01 FLOW per MB)
- **Upload Timestamp**: When media was uploaded to Flow storage

#### Verification System
The `Verification` struct ensures catch authenticity:
- **Verifier**: Entity performing verification
- **Timestamp**: Verification completion time
- **Method**: Verification technique used
- **Confidence**: Numerical confidence score (0.0-1.0)
- **Metadata**: Additional verification context

### Data Privacy Model

#### Public Data
Accessible to all users and marketplaces:
- Date of catch, species, length
- Angler identification
- Pricing information
- Physical fish rights status
- Release status
- Catch reel details

#### Private Data
Restricted to NFT owner access:
- Geographic coordinates
- Exact timestamp
- Weather conditions
- Angler-added notes
- AI analysis results
- Scale pattern hash

## Technical Implementation

### NFT Resource
The `NFT` resource implements Flow's `NonFungibleToken.INFT` interface with additional metadata views. Each NFT contains immutable catch data and provides access to both public and private information through controlled methods.

### Collection Management
The `Collection` resource enables users to manage multiple FishCards through standard NFT collection interfaces. It supports deposit/withdrawal operations and provides borrowing capabilities for metadata access.

### Minting Process
The `Minter` resource controls NFT creation with comprehensive validation:
1. Increment total supply counter
2. Generate unique NFT ID
3. Create NFT with all required data structures
4. Emit minting event for tracking

### Metadata Views
The contract implements Flow's `MetadataViews` standard for marketplace compatibility:
- **Display**: Name, description, thumbnail, attributes
- **Collection Data**: Storage paths and collection interfaces
- **Collection Display**: Contract-level metadata
- **Royalties**: Currently configured as none

## Security Considerations

### Access Control
- **Public Data**: Readable by all users
- **Private Data**: Restricted to NFT owner via `getPrivateData()` method
- **Minting**: Controlled through minter resource authorization
- **Administration**: Limited to admin resource holders

### Data Integrity
- Media content verified through cryptographic hashes
- Flow decentralized storage ensures content permanence and availability
- FLOW token staking requirement ensures storage capacity and prevents data loss
- Verification confidence scoring prevents low-quality submissions
- Immutable NFT data prevents post-mint modifications
- Event logging provides audit trail including storage events

### Storage Security
- Resources stored in user accounts, not centralized
- Capability-based access control
- Private data accessible only through owner's collection

## Integration Points

### API Integration
The contract is designed to integrate with the DerbyFish API (`app.py`) for:
- Submission processing and validation
- Media upload to Flow decentralized storage with FLOW token staking
- Hash verification and storage size calculation
- Verification workflow management
- NFT minting upon successful verification and storage confirmation

### Marketplace Compatibility
Standard NFT interfaces ensure compatibility with:
- Flow NFT marketplaces
- Wallet applications
- Metadata display systems
- Trading platforms

## Usage Patterns

### For Anglers
1. Submit catch data through DerbyFish API
2. Upload media to Flow decentralized storage (requires FLOW token staking)
3. Provide verification details and media size information
4. Receive minted FishCard NFT upon approval and storage confirmation
5. Access private data and monitor media storage requirements through owned collection

### For Tournament Organizers
1. Verify catch submissions using contract data
2. Access public information for leaderboards
3. Validate physical fish rights for prizes
4. Track catch statistics through events

### For Developers
1. Query public metadata for display
2. Integrate with collection interfaces
3. Monitor minting events for analytics
4. Access verification data for validation

## Event System

The contract emits four event types:
- **ContractInitialized**: Contract deployment confirmation
- **FishCardMinted**: New NFT creation with catch details
- **FishCardTransferred**: Ownership changes for tracking
- **MediaStored**: Media upload confirmation with storage size and stake requirements

## Flow Storage Economics

### Storage Staking Model
- **Stake-based storage**: Accounts must hold FLOW tokens as collateral for storage capacity
- **Rate**: 0.01 FLOW tokens per MB of storage (1 FLOW = 100 MB)
- **No fees**: FLOW tokens are not spent, only reserved as collateral
- **Reclaimable**: When data is deleted, reserved FLOW tokens become available again

### Storage Management
- **Status monitoring**: NFT owners can check media storage size and stake requirements
- **Stake tracking**: Total FLOW stake required is visible in NFT attributes
- **Capacity management**: Storage capacity scales with FLOW token balance
- **Decentralized access**: Media accessible through Flow's decentralized network

### Cost Examples
- **1 MB media**: Requires 0.01 FLOW stake (~$0.0022 USD at current prices)
- **10 MB media**: Requires 0.1 FLOW stake (~$0.022 USD at current prices)
- **100 MB media**: Requires 1.0 FLOW stake (~$0.22 USD at current prices)

## Future Considerations

### Scalability
- Contract designed for high-volume minting
- Efficient storage patterns minimize gas costs
- Flow decentralized storage scales with network growth
- Event-based architecture supports analytics

### Extensibility
- Enum-based submission standards allow new verification methods
- Flexible metadata structures support additional data types
- Admin functions enable contract metadata updates

### Compliance
- Privacy controls meet data protection requirements
- Verification system ensures regulatory compliance
- Audit trail supports tournament validation needs

## Conclusion

FishCardV1 provides a robust foundation for digital catch verification in the DerbyFish ecosystem. The contract balances comprehensive data capture with privacy controls, ensuring both transparency for public verification and protection of sensitive angler information. The implementation follows Flow blockchain best practices while providing specialized functionality for fishing tournament applications.
