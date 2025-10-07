#!/usr/bin/env node
/**
 * Flow Wallet Sync Script
 *
 * This script syncs wallet data between the database and flow-production.json:
 * 1. Fetches all wallet data from Supabase database
 * 2. Updates flow-production.json with current database state
 * 3. Ensures pkey files are in the correct pkeys/ subdirectory
 * 4. Handles missing or corrupted wallet data gracefully
 *
 * Usage:
 *    node syncWallets.js
 */

const { createClient } = require('@supabase/supabase-js');
const { config } = require('dotenv');
const { FlowWrapper } = require('./flowWrapper');
const fs = require('fs').promises;
const path = require('path');
const { performance } = require('perf_hooks');

// Load environment variables from .env file
config();

// Configuration
const NETWORK = "mainnet";

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

class WalletSyncer {
    constructor() {
        this.supabase = null;
        this.flowDir = './flow';
        this.accountsDir = path.join(this.flowDir, 'accounts');
        this.pkeysDir = path.join(this.accountsDir, 'pkeys');
        this.productionFile = path.join(this.accountsDir, 'flow-production.json');
        
        // Initialize Flow wrapper
        this.flowWrapper = new FlowWrapper({
            network: 'mainnet',
            flowDir: this.flowDir,
            timeout: 60,
            maxRetries: 3,
            rateLimitDelay: 0.2,
            jsonOutput: true
        });
        
        // Statistics (thread-safe)
        this.totalWallets = 0;
        this.syncedWallets = 0;
        this.missingPkeys = 0;
        this.corruptedWallets = 0;
        this.algorithmUpdates = 0;
        this.algorithmErrors = 0;
        this.vaultsCreated = 0;
        this.vaultCreationErrors = 0;
        this.vaultsAlreadyExist = 0;
        this.vaultCheckErrors = 0;
        this.flowBalanceChecks = 0;
        this.flowFundingNeeded = 0;
        this.flowFundingSuccess = 0;
        this.flowFundingErrors = 0;
        
        // Account assignment for threading (1 account per thread)
        this.funderAccounts = [
            "mainnet-agfarms", "mainnet-agfarms-1", "mainnet-agfarms-2", 
            "mainnet-agfarms-3", "mainnet-agfarms-4", "mainnet-agfarms-5",
            "mainnet-agfarms-6", "mainnet-agfarms-7", "mainnet-agfarms-8"
        ];
        this.threadAccounts = {}; // Will store thread_id -> account mapping
        
        // Global rate limiting (IP-based) - Flow RPC limits
        this.lastScriptRequestTime = 0; // For ExecuteScript (5 RPS limit)
        this.lastTransactionRequestTime = 0; // For SendTransaction (50 RPS limit)
        this.scriptRequestInterval = 0.2; // 200ms between script requests (5 RPS = 1 per 200ms)
        this.transactionRequestInterval = 0.02; // 20ms between transaction requests (50 RPS = 1 per 20ms)
    }

    getThreadAccount(threadId) {
        if (!(threadId in this.threadAccounts)) {
            // Assign next available account to this thread
            const accountIndex = Object.keys(this.threadAccounts).length % this.funderAccounts.length;
            this.threadAccounts[threadId] = this.funderAccounts[accountIndex];
            console.log(`🔑 Assigned account ${this.threadAccounts[threadId]} to thread ${threadId}`);
        }
        return this.threadAccounts[threadId];
    }

    async rateLimitScriptRequest() {
        const currentTime = performance.now() / 1000;
        const timeSinceLast = currentTime - this.lastScriptRequestTime;
        
        if (timeSinceLast < this.scriptRequestInterval) {
            const sleepTime = (this.scriptRequestInterval - timeSinceLast) * 1000;
            const threadId = process.pid; // Use process ID as thread identifier
            console.log(`⏳ Script rate limiting: sleeping ${sleepTime.toFixed(3)}s (Thread: ${threadId})`);
            await new Promise(resolve => setTimeout(resolve, sleepTime));
        }
        
        this.lastScriptRequestTime = performance.now() / 1000;
    }

    async rateLimitTransactionRequest() {
        const currentTime = performance.now() / 1000;
        const timeSinceLast = currentTime - this.lastTransactionRequestTime;
        
        if (timeSinceLast < this.transactionRequestInterval) {
            const sleepTime = (this.transactionRequestInterval - timeSinceLast) * 1000;
            const threadId = process.pid; // Use process ID as thread identifier
            console.log(`⏳ Transaction rate limiting: sleeping ${sleepTime.toFixed(3)}s (Thread: ${threadId})`);
            await new Promise(resolve => setTimeout(resolve, sleepTime));
        }
        
        this.lastTransactionRequestTime = performance.now() / 1000;
    }

    async getSupabaseClient() {
        try {
            if (!SUPABASE_URL) {
                console.log("Error: SUPABASE_URL not set in .env file");
                return null;
            }
                
            if (!SUPABASE_SERVICE_KEY) {
                console.log("Error: SUPABASE_SERVICE_ROLE_KEY not set in .env file");
                return null;
            }
            
            const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
            return supabase;
        } catch (error) {
            console.log(`Error initializing Supabase client: ${error.message}`);
            return null;
        }
    }

    async getAllWalletsFromDatabase() {
        try {
            const allWallets = [];
            let page = 1;
            const perPage = 1000;
            
            console.log(`🔍 Fetching wallet data from database...`);
            
            while (true) {
                console.log(`📄 Fetching page ${page} (per_page=${perPage})...`);
                const { data, error } = await this.supabase
                    .from('wallet')
                    .select('*')
                    .range((page - 1) * perPage, page * perPage - 1);
                
                if (error) {
                    console.log(`Error fetching wallets: ${error.message}`);
                    break;
                }
                
                if (!data || data.length === 0) {
                    console.log(`📄 Page ${page} returned no wallets, stopping pagination`);
                    break;
                }
                
                console.log(`📄 Page ${page} returned ${data.length} wallets`);
                allWallets.push(...data);
                
                if (data.length < perPage) {
                    console.log(`📄 Page ${page} had fewer wallets than per_page, stopping pagination`);
                    break;
                }
                    
                page += 1;
            }
            
            console.log(`📊 Total wallets fetched from database: ${allWallets.length}`);
            return allWallets;
            
        } catch (error) {
            console.log(`Error fetching wallets from database: ${error.message}`);
            return [];
        }
    }

    async checkWalletSignatureAlgorithm(flowAddress) {
        try {
            // Ensure address has 0x prefix
            if (!flowAddress.startsWith('0x')) {
                flowAddress = '0x' + flowAddress;
            }
            
            // Use Flow wrapper to get account information
            const result = await this.flowWrapper.getAccount(flowAddress, 30);
            
            if (!result.success) {
                console.log(`⚠️  Error checking algorithm for ${flowAddress}: ${result.errorMessage}`);
                return [null, null];
            }
            
            // Extract signature algorithm info from the first key
            if (result.data && result.data.keys && result.data.keys.length > 0) {
                // The keys field is now an array of strings (public keys), not objects
                // We need to get the key details separately
                const keyPublicKey = result.data.keys[0];
                
                // For now, we'll use defaults since the Flow CLI format has changed
                // In the future, we might need to use a different command to get key details
                let signatureAlgo = "ECDSA_P256"; // Default to P256
                let hashAlgo = "SHA3_256"; // Default to SHA3_256
                
                console.log(`🔍 Key found: ${keyPublicKey.substring(0, 20)}... (using defaults for algorithm)`);
                
                // Convert Flow CLI format to our config format
                if (signatureAlgo === 'ECDSA_P256') {
                    signatureAlgo = 'ECDSA_P256';
                } else if (signatureAlgo === 'ECDSA_secp256k1') {
                    signatureAlgo = 'ECDSA_secp256k1';
                }
                
                if (hashAlgo === 'SHA3_256') {
                    hashAlgo = 'SHA3_256';
                } else if (hashAlgo === 'SHA2_256') {
                    hashAlgo = 'SHA2_256';
                }
                
                return [signatureAlgo, hashAlgo];
            } else {
                console.log(`⚠️  No keys found for address ${flowAddress}`);
                return [null, null];
            }
                
        } catch (error) {
            console.log(`⚠️  Error checking algorithm for ${flowAddress}: ${error.message}`);
            return [null, null];
        }
    }

    async checkFlowBalance(flowAddress) {
        try {
            // Ensure address has 0x prefix
            if (!flowAddress.startsWith('0x')) {
                flowAddress = '0x' + flowAddress;
            }
            
            // Use Flow wrapper to execute script
            const result = await this.flowWrapper.executeScript(
                "cadence/scripts/checkFlowBalance.cdc",
                [flowAddress],
                30
            );
            
            if (!result.success) {
                // Check if it's a rate limit error
                if (result.errorMessage.toLowerCase().includes("rate limited") || result.errorMessage.includes("ResourceExhausted")) {
                    const threadId = process.pid;
                    console.log(`⚠️  Rate limited checking FLOW balance for ${flowAddress}`);
                    console.log(`   📋 Full error: ${result.errorMessage.trim()}`);
                    console.log(`   🔍 Command: ${result.command}`);
                    console.log(`   🧵 Thread ID: ${threadId}`);
                    return null;
                }
                console.log(`⚠️  Error checking FLOW balance for ${flowAddress}: ${result.errorMessage}`);
                return null;
            }
            
            // Parse JSON output
            try {
                const balanceData = result.data;
                
                // The script returns a dictionary with key-value pairs
                if (balanceData && balanceData.value && Array.isArray(balanceData.value)) {
                    // Find the FLOW_Balance entry in the value array
                    for (const item of balanceData.value) {
                        if (item && 
                            typeof item === 'object' && 
                            item.key && item.value &&
                            item.key.value === "FLOW_Balance") {
                            const balanceStr = item.value.value || "0.0";
                            const balance = parseFloat(balanceStr);
                            return balance;
                        }
                    }
                    
                    // If FLOW_Balance not found, return 0
                    console.log(`FLOW_Balance not found in response for ${flowAddress}`);
                    return 0.0;
                } else {
                    console.log(`Unexpected response format for ${flowAddress}: ${JSON.stringify(balanceData)}`);
                    return null;
                }
                    
            } catch (parseError) {
                console.log(`Error parsing FLOW balance result for ${flowAddress}: ${parseError.message}`);
                return null;
            }
            
        } catch (error) {
            console.log(`⚠️  Error checking FLOW balance for ${flowAddress}: ${error.message}`);
            return null;
        }
    }

    async fundWalletWithFlow(flowAddress, amount = 0.1, threadId = null) {
        try {
            // Get thread-specific funder account
            if (threadId === null) {
                threadId = process.pid;
            }
            const funderAccount = this.getThreadAccount(threadId);
            
            // Ensure address has 0x prefix
            if (!flowAddress.startsWith('0x')) {
                flowAddress = '0x' + flowAddress;
            }
            
            console.log(`🔍 DEBUG: Funding ${flowAddress} with ${amount} FLOW`);
            console.log(`🔍 DEBUG: Using account: ${funderAccount}`);
            
            // Use Flow wrapper to send transaction
            const result = await this.flowWrapper.sendTransaction(
                "cadence/transactions/fundWallet.cdc",
                [flowAddress, amount.toString()],
                { signer: funderAccount },
                60
            );
            
            console.log(`🔍 DEBUG: Return code: ${result.success ? 0 : 1}`);
            console.log(`🔍 DEBUG: Stdout: ${result.rawOutput}`);
            console.log(`🔍 DEBUG: Stderr: ${result.errorMessage}`);
            
            if (!result.success) {
                // Check if it's a rate limit error
                if (result.errorMessage.toLowerCase().includes("rate limited") || result.errorMessage.includes("ResourceExhausted")) {
                    console.log(`⚠️  Rate limited funding ${flowAddress} with ${amount} FLOW`);
                    console.log(`   📋 Full error: ${result.errorMessage.trim()}`);
                    console.log(`   🔍 Command: ${result.command}`);
                    console.log(`   🔑 Using account: ${funderAccount}`);
                } else {
                    console.log(`❌ Error funding ${flowAddress} with ${amount} FLOW: ${result.errorMessage}`);
                }
                return false;
            }
            
            if (result.transactionId) {
                console.log(`✓ Funded ${flowAddress} with ${amount} FLOW (Transaction: ${result.transactionId})`);
            } else {
                console.log(`✓ Funded ${flowAddress} with ${amount} FLOW`);
            }
            
            return true;
                
        } catch (error) {
            console.log(`❌ Error funding ${flowAddress} with ${amount} FLOW: ${error.message}`);
            return false;
        }
    }

    async checkBaitVaultExists(flowAddress) {
        try {
            // Ensure address has 0x prefix
            if (!flowAddress.startsWith('0x')) {
                flowAddress = '0x' + flowAddress;
            }
            
            // Use Flow wrapper to execute script
            const result = await this.flowWrapper.executeScript(
                "cadence/scripts/checkBaitBalance.cdc",
                [flowAddress],
                30
            );
            
            if (result.success) {
                // Script executed successfully, vault exists (even if balance is 0)
                return true;
            } else {
                // Check if error is about vault not existing
                if (result.errorMessage.includes("Could not borrow BAIT vault reference")) {
                    return false;
                }
                // Check if it's a rate limit error
                else if (result.errorMessage.toLowerCase().includes("rate limited") || result.errorMessage.includes("ResourceExhausted")) {
                    const threadId = process.pid;
                    console.log(`⚠️  Rate limited checking vault for ${flowAddress}`);
                    console.log(`   📋 Full error: ${result.errorMessage.trim()}`);
                    console.log(`   🔍 Command: ${result.command}`);
                    console.log(`   🧵 Thread ID: ${threadId}`);
                    return null;
                } else {
                    // Some other error occurred
                    console.log(`⚠️  Error checking vault for ${flowAddress}: ${result.errorMessage}`);
                    return null;
                }
            }
                    
        } catch (error) {
            console.log(`⚠️  Error checking vault for ${flowAddress}: ${error.message}`);
            return null;
        }
    }

    async createBaitVault(flowAddress, authId, threadId = null) {
        try {
            // Get thread-specific payer account
            if (threadId === null) {
                threadId = process.pid;
            }
            const payerAccount = this.getThreadAccount(threadId);
            
            console.log(`🔍 Creating vault for address: ${flowAddress}, auth_id: ${authId}`);
            
            // Use Flow wrapper to send transaction
            const result = await this.flowWrapper.sendTransaction(
                "cadence/transactions/createAllVault.cdc",
                [`0x${flowAddress}`],
                { 
                    signer: flowAddress, // Signer (target address)
                    payer: payerAccount // Rotating payer for fees
                },
                60
            );
            
            console.log(`🔍 DEBUG: Return code: ${result.success ? 0 : 1}`);
            console.log(`🔍 DEBUG: Stdout: ${result.rawOutput}`);
            console.log(`🔍 DEBUG: Stderr: ${result.errorMessage}`);
            
            if (!result.success) {
                // Check if it's a rate limit error
                if (result.errorMessage.toLowerCase().includes("rate limited") || result.errorMessage.includes("ResourceExhausted")) {
                    console.log(`⚠️  Rate limited creating vault for ${authId} (${flowAddress})`);
                    console.log(`   📋 Full error: ${result.errorMessage.trim()}`);
                    console.log(`   🔍 Command: ${result.command}`);
                    console.log(`   🔑 Using payer: ${payerAccount}`);
                } else {
                    console.log(`❌ Error creating vault for ${authId} (${flowAddress}): ${result.errorMessage}`);
                }
                return false;
            }
            
            console.log(`✓ Created BaitCoin vault for ${authId} (${flowAddress})`);
            return true;
                
        } catch (error) {
            console.log(`❌ Error creating vault for ${authId} (${flowAddress}): ${error.message}`);
            return false;
        }
    }

    validateWalletData(wallet) {
        const requiredFields = ['auth_id', 'flow_address', 'flow_private_key', 'flow_public_key'];
        
        for (const field of requiredFields) {
            if (!wallet[field]) {
                console.log(`⚠️  Wallet ${wallet.auth_id || 'unknown'} missing ${field}`);
                return false;
            }
        }
        
        return true;
    }

    async checkPkeyFileExists(authId) {
        const pkeyFile = path.join(this.pkeysDir, `${authId}.pkey`);
        try {
            await fs.access(pkeyFile);
            return true;
        } catch {
            return false;
        }
    }

    async createPkeyFile(authId, privateKey) {
        try {
            await fs.mkdir(this.pkeysDir, { recursive: true });
            const pkeyFile = path.join(this.pkeysDir, `${authId}.pkey`);
            
            await fs.writeFile(pkeyFile, privateKey);
            
            console.log(`✓ Created pkey file: ${pkeyFile}`);
            return true;
        } catch (error) {
            console.log(`❌ Error creating pkey file for ${authId}: ${error.message}`);
            return false;
        }
    }

    async updateWalletAlgorithmInDatabase(authId, signatureAlgorithm, hashAlgorithm) {
        try {
            // Only update signature_algorithm for now since other columns don't exist
            const { data, error } = await this.supabase
                .from('wallet')
                .update({
                    signature_algorithm: signatureAlgorithm
                })
                .eq('auth_id', authId);
            
            if (error) {
                console.log(`Error updating algorithm for ${authId}: ${error.message}`);
                return false;
            }
            
            if (data) {
                console.log(`✓ Updated algorithm for ${authId}: ${signatureAlgorithm} + ${hashAlgorithm}`);
                return true;
            } else {
                console.log(`⚠️  No wallet found with auth_id ${authId}`);
                return false;
            }
                
        } catch (error) {
            console.log(`❌ Error updating algorithm for ${authId}: ${error.message}`);
            return false;
        }
    }

    async ensureAlgorithmColumnsExist() {
        try {
            // Try to add the columns if they don't exist
            // Note: This is a simplified approach - in production you'd want proper migrations
            // For now, we'll assume the columns exist or will be added manually
        } catch (error) {
            console.log(`⚠️  Note: Algorithm columns may not exist in database: ${error.message}`);
            console.log("Please add signature_algorithm and hash_algorithm columns to the wallet table");
        }
    }

    async loadExistingProductionConfig() {
        try {
            await fs.access(this.productionFile);
            const data = await fs.readFile(this.productionFile, 'utf8');
            return JSON.parse(data);
        } catch (error) {
            console.log(`⚠️  Error loading existing flow-production.json: ${error.message}`);
            return { accounts: {} };
        }
    }

    async processWallet(wallet) {
        const authId = wallet.auth_id;
        const threadId = process.pid;
        
        try {
            // Validate wallet data
            if (!this.validateWalletData(wallet)) {
                this.corruptedWallets += 1;
                return null;
            }
            
            // Check if pkey file exists
            if (!(await this.checkPkeyFileExists(authId))) {
                console.log(`⚠️  Missing pkey file for ${authId}, creating it...`);
                if (!(await this.createPkeyFile(authId, wallet.flow_private_key))) {
                    this.missingPkeys += 1;
                    return null;
                }
            }
            
            // Get signature algorithm from database or use defaults
            const signatureAlgorithm = wallet.signature_algorithm || 'ECDSA_P256';
            const hashAlgorithm = wallet.hash_algorithm || 'SHA3_256';
            
            // Check FLOW balance first
            console.log(`🔍 Checking FLOW balance for ${authId} (${wallet.flow_address})...`);
            const flowBalance = await this.checkFlowBalance(wallet.flow_address);
            
            this.flowBalanceChecks += 1;
            
            if (flowBalance !== null) {
                console.log(`💰 FLOW balance: ${flowBalance} FLOW`);
                
                // Check if funding is needed (below 0.075 FLOW)
                if (flowBalance < 0.075) {
                    console.log(`💸 FLOW balance below 0.075, funding with 0.1 FLOW...`);
                    this.flowFundingNeeded += 1;
                    
                    if (await this.fundWalletWithFlow(wallet.flow_address, 0.1, threadId)) {
                        this.flowFundingSuccess += 1;
                        console.log(`✓ Successfully funded ${authId} with 0.1 FLOW`);
                    } else {
                        this.flowFundingErrors += 1;
                        console.log(`❌ Failed to fund ${authId} with FLOW`);
                    }
                } else {
                    console.log(`✅ FLOW balance sufficient (${flowBalance} FLOW)`);
                }
            } else {
                console.log(`⚠️  Could not check FLOW balance for ${authId}`);
            }
            
            // Check if BaitCoin vault already exists
            console.log(`🔍 Checking if BaitCoin vault exists for ${authId} (${wallet.flow_address})...`);
            const vaultExists = await this.checkBaitVaultExists(wallet.flow_address);
            
            if (vaultExists === true) {
                console.log(`✓ BaitCoin vault already exists for ${authId} (${wallet.flow_address})`);
                this.vaultsAlreadyExist += 1;
            } else if (vaultExists === false) {
                // Vault doesn't exist, create it
                console.log(`🔍 Creating BaitCoin vault for ${authId} (${wallet.flow_address})...`);
                if (await this.createBaitVault(wallet.flow_address, authId, threadId)) {
                    this.vaultsCreated += 1;
                } else {
                    this.vaultCreationErrors += 1;
                }
            } else {
                // Error checking vault existence
                console.log(`⚠️  Could not check vault existence for ${authId} (${wallet.flow_address})`);
                this.vaultCheckErrors += 1;
            }
            
            // Return wallet config for production file
            const walletConfig = {
                address: wallet.flow_address,
                key: {
                    type: "file",
                    location: `accounts/pkeys/${authId}.pkey`,
                    signatureAlgorithm: signatureAlgorithm,
                    hashAlgorithm: hashAlgorithm
                }
            };
            
            this.syncedWallets += 1;
            
            return { [authId]: walletConfig };
            
        } catch (error) {
            console.log(`❌ Error processing wallet ${authId}: ${error.message}`);
            this.corruptedWallets += 1;
            return null;
        }
    }

    async createProductionConfig(wallets) {
        const productionConfig = {
            accounts: {}
        };
        
        console.log(`🚀 Processing ${wallets.length} wallets with threading...`);
        console.log(`🔄 Using ${this.funderAccounts.length} dedicated accounts (1 per thread)`);
        console.log(`⏳ Script rate limiting: ${this.scriptRequestInterval}s between ExecuteScript requests (5 RPS limit)`);
        console.log(`⏳ Transaction rate limiting: ${this.transactionRequestInterval}s between SendTransaction requests (50 RPS limit)`);
        console.log(`🧵 Using 2 threads to respect Flow network rate limits`);
        
        // Process wallets in parallel (reduced to 2 workers to respect IP rate limits)
        const concurrencyLimit = 2;
        const results = [];
        
        for (let i = 0; i < wallets.length; i += concurrencyLimit) {
            const batch = wallets.slice(i, i + concurrencyLimit);
            const batchPromises = batch.map(async (wallet) => {
                try {
                    return await this.processWallet(wallet);
                } catch (error) {
                    console.log(`❌ Error processing wallet ${wallet.auth_id || 'unknown'}: ${error.message}`);
                    this.corruptedWallets += 1;
                    return null;
                }
            });
            
            const batchResults = await Promise.all(batchPromises);
            results.push(...batchResults);
        }
        
        // Collect results
        for (const result of results) {
            if (result) {
                Object.assign(productionConfig.accounts, result);
            }
        }
        
        return productionConfig;
    }

    async saveProductionConfig(config) {
        try {
            // Create backup of existing file
            try {
                await fs.access(this.productionFile);
                const backupFile = this.productionFile.replace('.json', '.json.backup');
                await fs.rename(this.productionFile, backupFile);
                console.log(`📋 Created backup: ${backupFile}`);
            } catch {
                // File doesn't exist, no backup needed
            }
            
            // Write new config
            await fs.writeFile(this.productionFile, JSON.stringify(config, null, 4));
            
            console.log(`✓ Saved flow-production.json with ${Object.keys(config.accounts).length} accounts`);
            return true;
        } catch (error) {
            console.log(`❌ Error saving flow-production.json: ${error.message}`);
            return false;
        }
    }

    async cleanupOrphanedPkeyFiles(validAuthIds) {
        try {
            try {
                await fs.access(this.pkeysDir);
            } catch {
                return; // Directory doesn't exist
            }
            
            const files = await fs.readdir(this.pkeysDir);
            const orphanedFiles = [];
            
            for (const file of files) {
                if (file.endsWith('.pkey')) {
                    const authId = file.replace('.pkey', '');
                    if (!validAuthIds.has(authId)) {
                        orphanedFiles.push(path.join(this.pkeysDir, file));
                    }
                }
            }
            
            if (orphanedFiles.length > 0) {
                console.log(`🧹 Found ${orphanedFiles.length} orphaned pkey files:`);
                for (const file of orphanedFiles) {
                    console.log(`  - ${path.basename(file)}`);
                }
                
                // Ask for confirmation before deleting
                const readline = require('readline');
                const rl = readline.createInterface({
                    input: process.stdin,
                    output: process.stdout
                });
                
                const answer = await new Promise((resolve) => {
                    rl.question('Delete orphaned pkey files? (y/N): ', resolve);
                });
                
                rl.close();
                
                if (answer.toLowerCase() === 'y') {
                    for (const file of orphanedFiles) {
                        await fs.unlink(file);
                        console.log(`✓ Deleted ${path.basename(file)}`);
                    }
                } else {
                    console.log("Skipped deletion of orphaned files");
                }
            } else {
                console.log("✓ No orphaned pkey files found");
            }
                
        } catch (error) {
            console.log(`⚠️  Error during cleanup: ${error.message}`);
        }
    }

    async run() {
        console.log("🔄 Starting wallet sync process...");
        console.log("This will sync database wallet data with flow-production.json");
        
        // Ensure we're in the right directory
        const fs = require('fs');
        if (!fs.existsSync(this.flowDir)) {
            console.log("Error: flow directory not found. Please run this script from the project root.");
            process.exit(1);
        }
        
        // Flow CLI commands will run from the flow directory explicitly
        console.log(`📁 Flow CLI commands will run from: ${this.flowDir}`);
        
        // Initialize Supabase client
        this.supabase = await this.getSupabaseClient();
        if (!this.supabase) {
            console.log("Error: Could not initialize Supabase client.");
            console.log("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.");
            process.exit(1);
        }
        
        // Get all wallets from database
        const wallets = await this.getAllWalletsFromDatabase();
        if (!wallets || wallets.length === 0) {
            console.log("No wallets found in database.");
            process.exit(0);
        }
        
        this.totalWallets = wallets.length;
        console.log(`📊 Processing ${this.totalWallets} wallets...`);
        
        // Create production config from database data
        const productionConfig = await this.createProductionConfig(wallets);
        
        // Save production config
        if (!(await this.saveProductionConfig(productionConfig))) {
            console.log("❌ Failed to save production config");
            process.exit(1);
        }
        
        // Cleanup orphaned pkey files
        const validAuthIds = new Set(Object.keys(productionConfig.accounts));
        await this.cleanupOrphanedPkeyFiles(validAuthIds);
        
        // Print summary
        console.log(`\n🎉 Sync Summary:`);
        console.log(`- Total wallets in database: ${this.totalWallets}`);
        console.log(`- Successfully synced: ${this.syncedWallets}`);
        console.log(`- Corrupted wallets (skipped): ${this.corruptedWallets}`);
        console.log(`- Missing pkey files (created): ${this.missingPkeys}`);
        console.log(`- Algorithm updates: ${this.algorithmUpdates}`);
        console.log(`- Algorithm errors: ${this.algorithmErrors}`);
        console.log(`- FLOW balance checks: ${this.flowBalanceChecks}`);
        console.log(`- FLOW funding needed: ${this.flowFundingNeeded}`);
        console.log(`- FLOW funding successful: ${this.flowFundingSuccess}`);
        console.log(`- FLOW funding errors: ${this.flowFundingErrors}`);
        console.log(`- BaitCoin vaults already exist: ${this.vaultsAlreadyExist}`);
        console.log(`- BaitCoin vaults created: ${this.vaultsCreated}`);
        console.log(`- Vault creation errors: ${this.vaultCreationErrors}`);
        console.log(`- Vault check errors: ${this.vaultCheckErrors}`);
        console.log(`- Production config saved to: ${this.productionFile}`);
        
        // Print Flow wrapper metrics
        const flowMetrics = this.flowWrapper.getMetrics();
        console.log(`\n📊 Flow CLI Operations Summary:`);
        console.log(`- Total operations: ${flowMetrics.total_operations}`);
        console.log(`- Successful operations: ${flowMetrics.successful_operations}`);
        console.log(`- Failed operations: ${flowMetrics.failed_operations}`);
        console.log(`- Success rate: ${flowMetrics.success_rate_percent}%`);
        console.log(`- Average execution time: ${flowMetrics.average_execution_time}s`);
        console.log(`- Total retries: ${flowMetrics.total_retries}`);
        console.log(`- Rate limited operations: ${flowMetrics.rate_limited_operations}`);
        console.log(`- Timeout operations: ${flowMetrics.timeout_operations}`);
        
        if (this.syncedWallets === 0) {
            console.log("⚠️  No wallets were successfully synced!");
            process.exit(1);
        } else {
            console.log("✅ Sync completed successfully!");
        }
    }
}

async function main() {
    const syncer = new WalletSyncer();
    await syncer.run();
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = { WalletSyncer };
