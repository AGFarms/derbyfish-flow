access(all) contract Fishdex {

    // REGISTRY DATA STRUCTURES - Lightweight coordination only
    access(all) struct SpeciesRegistryEntry {
        access(all) let contractAddress: Address
        access(all) let speciesCode: String
        access(all) let ticker: String
        access(all) let commonName: String
        access(all) let scientificName: String
        access(all) let family: String
        access(all) let registeredAt: UFix64
        access(all) let registeredBy: Address
        access(all) var isActive: Bool
        access(all) var lastUpdated: UFix64
        
        init(
            contractAddress: Address,
            speciesCode: String,
            ticker: String,
            commonName: String,
            scientificName: String,
            family: String,
            registeredBy: Address
        ) {
            self.contractAddress = contractAddress
            self.speciesCode = speciesCode
            self.ticker = ticker
            self.commonName = commonName
            self.scientificName = scientificName
            self.family = family
            self.registeredAt = getCurrentBlock().timestamp
            self.registeredBy = registeredBy
            self.isActive = true
            self.lastUpdated = getCurrentBlock().timestamp
        }
        
        access(all) fun deactivate() {
            self.isActive = false
            self.lastUpdated = getCurrentBlock().timestamp
        }
        
        access(all) fun reactivate() {
            self.isActive = true
            self.lastUpdated = getCurrentBlock().timestamp
        }
    }

    // REGISTRY STORAGE - Multiple lookup methods
    access(all) var registeredSpecies: {String: SpeciesRegistryEntry}          // speciesCode -> entry
    access(all) var speciesByTicker: {String: String}                          // ticker -> speciesCode
    access(all) var speciesByScientificName: {String: String}                  // scientificName -> speciesCode
    access(all) var speciesByCommonName: {String: String}                      // commonName -> speciesCode
    access(all) var speciesByAddress: {Address: String}                        // contractAddress -> speciesCode
    access(all) var totalRegisteredSpecies: UInt64
    access(all) var totalActiveSpecies: UInt64

    // ADMIN & GOVERNANCE
    access(all) var adminAddress: Address
    access(all) var registrationOpen: Bool
    access(all) var requiresApproval: Bool
    access(all) var pendingRegistrations: {String: SpeciesRegistryEntry}

    // STORAGE PATHS
    access(all) let AdminStoragePath: StoragePath
    access(all) let CoordinatorStoragePath: StoragePath
    access(all) let CoordinatorPublicPath: PublicPath

    // EVENTS - Complete tracking system
    access(all) event SpeciesRegistered(speciesCode: String, contractAddress: Address, ticker: String, registeredBy: Address)
    access(all) event SpeciesDeactivated(speciesCode: String, contractAddress: Address, deactivatedBy: Address)
    access(all) event SpeciesReactivated(speciesCode: String, contractAddress: Address, reactivatedBy: Address)
    access(all) event RegistrationRequested(speciesCode: String, contractAddress: Address, requestedBy: Address)
    access(all) event RegistrationApproved(speciesCode: String, contractAddress: Address, approvedBy: Address)
    access(all) event RegistrationRejected(speciesCode: String, contractAddress: Address, rejectedBy: Address)
    access(all) event AdminUpdated(oldAdmin: Address, newAdmin: Address)
    access(all) event RegistrationStatusChanged(open: Bool, requiresApproval: Bool, updatedBy: Address)
    access(all) event SpeciesLookupPerformed(speciesCode: String, requestedBy: Address?)
    access(all) event CrossContractCoordination(fromContract: Address, toContract: Address, operation: String)

    // ADMIN RESOURCE - Registry management
    access(all) resource Admin {
        
        // Approve pending registration
        access(all) fun approveRegistration(speciesCode: String) {
            pre {
                Fishdex.pendingRegistrations[speciesCode] != nil: "No pending registration for this species code"
                Fishdex.registeredSpecies[speciesCode] == nil: "Species already registered"
            }
            
            let entry = Fishdex.pendingRegistrations.remove(key: speciesCode)!
            Fishdex.registerSpeciesInternal(entry: entry)
            
            emit RegistrationApproved(
                speciesCode: speciesCode,
                contractAddress: entry.contractAddress,
                approvedBy: Fishdex.adminAddress
            )
        }
        
        // Reject pending registration
        access(all) fun rejectRegistration(speciesCode: String) {
            pre {
                Fishdex.pendingRegistrations[speciesCode] != nil: "No pending registration for this species code"
            }
            
            let entry = Fishdex.pendingRegistrations.remove(key: speciesCode)!
            
            emit RegistrationRejected(
                speciesCode: speciesCode,
                contractAddress: entry.contractAddress,
                rejectedBy: Fishdex.adminAddress
            )
        }
        
        // Force register species (bypass approval)
        access(all) fun forceRegisterSpecies(
            contractAddress: Address,
            speciesCode: String,
            ticker: String,
            commonName: String,
            scientificName: String,
            family: String
        ) {
            let entry = SpeciesRegistryEntry(
                contractAddress: contractAddress,
                speciesCode: speciesCode,
                ticker: ticker,
                commonName: commonName,
                scientificName: scientificName,
                family: family,
                registeredBy: Fishdex.adminAddress
            )
            
            Fishdex.registerSpeciesInternal(entry: entry)
        }
        
        // Deactivate species (remove from active registry)
        access(all) fun deactivateSpecies(speciesCode: String) {
            pre {
                Fishdex.registeredSpecies[speciesCode] != nil: "Species not found in registry"
                Fishdex.registeredSpecies[speciesCode]!.isActive: "Species already deactivated"
            }
            
            Fishdex.registeredSpecies[speciesCode]!.deactivate()
            Fishdex.totalActiveSpecies = Fishdex.totalActiveSpecies - 1
            
            emit SpeciesDeactivated(
                speciesCode: speciesCode,
                contractAddress: Fishdex.registeredSpecies[speciesCode]!.contractAddress,
                deactivatedBy: Fishdex.adminAddress
            )
        }
        
        // Reactivate species
        access(all) fun reactivateSpecies(speciesCode: String) {
            pre {
                Fishdex.registeredSpecies[speciesCode] != nil: "Species not found in registry"
                !Fishdex.registeredSpecies[speciesCode]!.isActive: "Species already active"
            }
            
            Fishdex.registeredSpecies[speciesCode]!.reactivate()
            Fishdex.totalActiveSpecies = Fishdex.totalActiveSpecies + 1
            
            emit SpeciesReactivated(
                speciesCode: speciesCode,
                contractAddress: Fishdex.registeredSpecies[speciesCode]!.contractAddress,
                reactivatedBy: Fishdex.adminAddress
            )
        }
        
        // Update admin address
        access(all) fun updateAdmin(newAdmin: Address) {
            let oldAdmin = Fishdex.adminAddress
            Fishdex.adminAddress = newAdmin
            emit AdminUpdated(oldAdmin: oldAdmin, newAdmin: newAdmin)
        }
        
        // Update registration settings
        access(all) fun updateRegistrationSettings(open: Bool, requiresApproval: Bool) {
            Fishdex.registrationOpen = open
            Fishdex.requiresApproval = requiresApproval
            emit RegistrationStatusChanged(open: open, requiresApproval: requiresApproval, updatedBy: Fishdex.adminAddress)
        }
        
        // Clear all pending registrations
        access(all) fun clearPendingRegistrations() {
            Fishdex.pendingRegistrations = {}
        }
        
        // Bulk approve multiple registrations
        access(all) fun bulkApproveRegistrations(speciesCodes: [String]) {
            for code in speciesCodes {
                if Fishdex.pendingRegistrations[code] != nil {
                    self.approveRegistration(speciesCode: code)
                }
            }
        }
    }

    // COORDINATOR RESOURCE - Cross-contract communication
    access(all) resource Coordinator {
        
        // Register species (public interface for species coins)
        access(all) fun registerSpecies(
            contractAddress: Address,
            speciesCode: String,
            ticker: String,
            commonName: String,
            scientificName: String,
            family: String
        ) {
            pre {
                Fishdex.registrationOpen: "Species registration is currently closed"
                Fishdex.registeredSpecies[speciesCode] == nil: "Species code already registered"
                Fishdex.speciesByTicker[ticker] == nil: "Ticker already registered"
                Fishdex.speciesByAddress[contractAddress] == nil: "Contract address already registered"
            }
            
            let entry = SpeciesRegistryEntry(
                contractAddress: contractAddress,
                speciesCode: speciesCode,
                ticker: ticker,
                commonName: commonName,
                scientificName: scientificName,
                family: family,
                registeredBy: contractAddress
            )
            
            if Fishdex.requiresApproval {
                // Add to pending registrations
                Fishdex.pendingRegistrations[speciesCode] = entry
                emit RegistrationRequested(
                    speciesCode: speciesCode,
                    contractAddress: contractAddress,
                    requestedBy: contractAddress
                )
            } else {
                // Auto-approve registration
                Fishdex.registerSpeciesInternal(entry: entry)
            }
        }
        
        // Species lookup for Fish NFT contracts
        access(all) view fun lookupSpeciesCoin(speciesCode: String): Address? {
            if let entry = Fishdex.registeredSpecies[speciesCode] {
                if entry.isActive {
                    return entry.contractAddress
                }
            }
            return nil
        }
        
        // Lookup by scientific name
        access(all) view fun lookupSpeciesCoinByScientificName(scientificName: String): Address? {
            if let speciesCode = Fishdex.speciesByScientificName[scientificName] {
                return self.lookupSpeciesCoin(speciesCode: speciesCode)
            }
            return nil
        }
        
        // Lookup by ticker
        access(all) view fun lookupSpeciesCoinByTicker(ticker: String): Address? {
            if let speciesCode = Fishdex.speciesByTicker[ticker] {
                return self.lookupSpeciesCoin(speciesCode: speciesCode)
            }
            return nil
        }
        
        // Lookup by common name
        access(all) view fun lookupSpeciesCoinByCommonName(commonName: String): Address? {
            if let speciesCode = Fishdex.speciesByCommonName[commonName] {
                return self.lookupSpeciesCoin(speciesCode: speciesCode)
            }
            return nil
        }
        
        // Species validation for Fish NFT contracts
        access(all) view fun validateSpecies(commonName: String, scientificName: String): String? {
            // Try lookup by scientific name first (most reliable)
            if let speciesCode = Fishdex.speciesByScientificName[scientificName] {
                if let entry = Fishdex.registeredSpecies[speciesCode] {
                    if entry.isActive {
                        return speciesCode
                    }
                }
            }
            
            // Fallback to common name lookup
            if let speciesCode = Fishdex.speciesByCommonName[commonName] {
                if let entry = Fishdex.registeredSpecies[speciesCode] {
                    if entry.isActive {
                        return speciesCode
                    }
                }
            }
            
            return nil
        }
        
        // Get species basic info for Fish NFT integration
        access(all) view fun getSpeciesInfo(speciesCode: String): {String: AnyStruct}? {
            if let entry = Fishdex.registeredSpecies[speciesCode] {
                if entry.isActive {
                    return {
                        "speciesCode": entry.speciesCode,
                        "ticker": entry.ticker,
                        "commonName": entry.commonName,
                        "scientificName": entry.scientificName,
                        "family": entry.family,
                        "contractAddress": entry.contractAddress
                    }
                }
            }
            return nil
        }
        
        // Coordinate species coin minting (called by Fish NFT)
        access(all) fun coordinateSpeciesCoinMinting(
            speciesCode: String,
            fishNFTId: UInt64,
            angler: Address,
            fishData: {String: AnyStruct}
        ): Bool {
            // Lookup species coin contract
            if let contractAddress = self.lookupSpeciesCoin(speciesCode: speciesCode) {
                
                // Prepare fish data for species coin
                let speciesCoinData: {String: AnyStruct} = {
                    "nftId": fishNFTId,
                    "speciesCode": speciesCode,
                    "angler": angler,
                    "fishData": fishData
                }
                
                // Get reference to species coin contract
                let speciesCoinAccount = getAccount(contractAddress)
                
                // Try to call species coin coordinator
                if let speciesCoinRef = speciesCoinAccount.capabilities.borrow<&AnyResource>(
                    /public/ExampleFishCoinFishDEXCoordinator
                ) {
                    // Note: This would call processCatchFromNFT on the species coin
                    emit CrossContractCoordination(
                        fromContract: Fishdex.account.address,
                        toContract: contractAddress,
                        operation: "SpeciesCoinMinting"
                    )
                    return true
                }
            }
            return false
        }
    }

    // PUBLIC QUERY FUNCTIONS - Frontend and external contract access

    // Registry browsing and discovery
    access(all) view fun getAllActiveSpecies(): [String] {
        var activeSpecies: [String] = []
        for speciesCode in self.registeredSpecies.keys {
            if self.registeredSpecies[speciesCode]!.isActive {
                activeSpecies = activeSpecies.concat([speciesCode])
            }
        }
        return activeSpecies
    }
    
    access(all) view fun getAllSpeciesByFamily(family: String): [String] {
        var matchingSpecies: [String] = []
        for speciesCode in self.registeredSpecies.keys {
            let entry = self.registeredSpecies[speciesCode]!
            if entry.family == family && entry.isActive {
                matchingSpecies = matchingSpecies.concat([speciesCode])
            }
        }
        return matchingSpecies
    }
    
    access(all) view fun searchSpeciesByName(searchTerm: String): [String] {
        var matchingSpecies: [String] = []
        let lowerSearchTerm = searchTerm.toLower()
        
        for speciesCode in self.registeredSpecies.keys {
            let entry = self.registeredSpecies[speciesCode]!
            if entry.isActive {
                let commonLower = entry.commonName.toLower()
                let scientificLower = entry.scientificName.toLower()
                
                if commonLower.contains(lowerSearchTerm) || scientificLower.contains(lowerSearchTerm) {
                    matchingSpecies = matchingSpecies.concat([speciesCode])
                }
            }
        }
        return matchingSpecies
    }
    
    // Registry statistics
    access(all) view fun getRegistryStats(): {String: UInt64} {
        return {
            "totalRegistered": self.totalRegisteredSpecies,
            "totalActive": self.totalActiveSpecies,
            "pendingApproval": UInt64(self.pendingRegistrations.length)
        }
    }
    
    // Species lookup functions (public interface)
    access(all) view fun getSpeciesEntry(speciesCode: String): SpeciesRegistryEntry? {
        return self.registeredSpecies[speciesCode]
    }
    
    access(all) view fun isSpeciesActive(speciesCode: String): Bool {
        if let entry = self.registeredSpecies[speciesCode] {
            return entry.isActive
        }
        return false
    }
    
    access(all) view fun getSpeciesContractAddress(speciesCode: String): Address? {
        if let entry = self.registeredSpecies[speciesCode] {
            if entry.isActive {
                return entry.contractAddress
            }
        }
        return nil
    }
    
    // Validation functions for external use
    access(all) view fun isSpeciesCodeAvailable(speciesCode: String): Bool {
        return self.registeredSpecies[speciesCode] == nil && self.pendingRegistrations[speciesCode] == nil
    }
    
    access(all) view fun isTickerAvailable(ticker: String): Bool {
        return self.speciesByTicker[ticker] == nil
    }
    
    access(all) view fun isContractAddressRegistered(contractAddress: Address): Bool {
        return self.speciesByAddress[contractAddress] != nil
    }
    
    // Admin and governance info
    access(all) view fun getAdminAddress(): Address {
        return self.adminAddress
    }
    
    access(all) view fun getRegistrationSettings(): {String: Bool} {
        return {
            "registrationOpen": self.registrationOpen,
            "requiresApproval": self.requiresApproval
        }
    }
    
    access(all) view fun getPendingRegistrations(): [String] {
        return self.pendingRegistrations.keys
    }
    
    access(all) view fun getPendingRegistrationInfo(speciesCode: String): SpeciesRegistryEntry? {
        return self.pendingRegistrations[speciesCode]
    }

    // INTERNAL HELPER FUNCTIONS
    access(contract) fun registerSpeciesInternal(entry: SpeciesRegistryEntry) {
        // Add to all lookup tables
        self.registeredSpecies[entry.speciesCode] = entry
        self.speciesByTicker[entry.ticker] = entry.speciesCode
        self.speciesByScientificName[entry.scientificName] = entry.speciesCode
        self.speciesByCommonName[entry.commonName] = entry.speciesCode
        self.speciesByAddress[entry.contractAddress] = entry.speciesCode
        
        // Update counters
        self.totalRegisteredSpecies = self.totalRegisteredSpecies + 1
        self.totalActiveSpecies = self.totalActiveSpecies + 1
        
        emit SpeciesRegistered(
            speciesCode: entry.speciesCode,
            contractAddress: entry.contractAddress,
            ticker: entry.ticker,
            registeredBy: entry.registeredBy
        )
    }

    // PUBLIC INTERFACE FUNCTIONS - Easy integration for other contracts
    access(all) fun createCoordinatorCapability(): Capability<&Coordinator> {
        return self.account.capabilities.storage.issue<&Coordinator>(self.CoordinatorStoragePath)
    }

    init() {
        // Initialize storage
        self.registeredSpecies = {}
        self.speciesByTicker = {}
        self.speciesByScientificName = {}
        self.speciesByCommonName = {}
        self.speciesByAddress = {}
        self.pendingRegistrations = {}
        
        // Initialize counters
        self.totalRegisteredSpecies = 0
        self.totalActiveSpecies = 0
        
        // Initialize admin settings
        self.adminAddress = self.account.address
        self.registrationOpen = true
        self.requiresApproval = false  // Start with auto-approval for initial deployment
        
        // Set storage paths
        self.AdminStoragePath = /storage/FishdexAdmin
        self.CoordinatorStoragePath = /storage/FishdexCoordinator
        self.CoordinatorPublicPath = /public/FishdexCoordinator
        
        // Create and store admin resource
        let admin <- create Admin()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
        
        // Create and store coordinator resource
        let coordinator <- create Coordinator()
        self.account.storage.save(<-coordinator, to: self.CoordinatorStoragePath)
        
        // Create public capability for coordinator
        let coordinatorCapability = self.account.capabilities.storage.issue<&Coordinator>(self.CoordinatorStoragePath)
        self.account.capabilities.publish(coordinatorCapability, at: self.CoordinatorPublicPath)
    }
}