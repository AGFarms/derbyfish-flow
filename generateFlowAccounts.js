#!/usr/bin/env node
/**
 * Flow Wallet Generator for All Users
 *
 * This script generates Flow wallets for all users in Supabase auth:
 * 1. Fetches all users from Supabase auth using service role
 * 2. Skips users who already have wallets
 * 3. Generates a unique Flow wallet for each user (multi-threaded)
 * 4. Saves private keys to flow/accounts/ directory
 * 5. Saves wallet data to the database
 *
 * Usage:
 *    node generateFlowAccounts.js
 */

const { createClient } = require('@supabase/supabase-js');
const { config } = require('dotenv');
const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const execAsync = promisify(exec);

// Load environment variables from .env file
config();

// Configuration
const NETWORK = "mainnet";
const TRANSACTION_TIMEOUT = 300; // 5 minutes timeout for transaction sealing
const RATE_LIMIT_DELAY = 1.0; // Delay between requests to avoid rate limiting
const MAX_WORKERS = 1; // Number of worker threads for wallet generation (must be 1 to avoid sequence conflicts)

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

class FlowWalletGenerator {
    constructor() {
        this.running = true;
        this.supabase = null;
        this.flowDir = './flow';
        this.flowBinary = null;
        this.transactionQueue = [];
        this.processingTransaction = false;
        this.walletsData = {};
        this.successfulWallets = 0;
        this.databaseSaves = 0;
        this.skippedWallets = 0;
        
        // Setup signal handlers for graceful shutdown
        process.on('SIGINT', () => this.signalHandler('SIGINT'));
        process.on('SIGTERM', () => this.signalHandler('SIGTERM'));
    }

    signalHandler(signal) {
        console.log(`\n🛑 Received signal ${signal}, shutting down gracefully...`);
        this.running = false;
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

    async getFlowBinary() {
        if (this.flowBinary) {
            return this.flowBinary;
        }
            
        try {
            const { stdout } = await execAsync('which flow');
            this.flowBinary = stdout.trim();
            return this.flowBinary;
        } catch (error) {
            console.log("Error: Flow CLI not found. Please install Flow CLI.");
            return null;
        }
    }

    async getExistingWallets() {
        try {
            const existingWallets = new Set();
            let page = 1;
            const perPage = 1000;
            
            while (true) {
                const { data, error } = await this.supabase
                    .from('wallet')
                    .select('auth_id')
                    .range((page - 1) * perPage, page * perPage - 1);
                
                if (error) {
                    console.log(`Error fetching existing wallets: ${error.message}`);
                    break;
                }
                
                if (!data || data.length === 0) {
                    break;
                }
                
                for (const wallet of data) {
                    existingWallets.add(wallet.auth_id);
                }
                
                if (data.length < perPage) {
                    break;
                }
                    
                page += 1;
            }
            
            console.log(`Found ${existingWallets.size} existing wallets in database`);
            return existingWallets;
            
        } catch (error) {
            console.log(`Error fetching existing wallets from database: ${error.message}`);
            return new Set();
        }
    }

    async getAllUsers() {
        try {
            // First get existing wallets
            const existingWallets = await this.getExistingWallets();
            
            const allUsers = [];
            let page = 1;
            const perPage = 1000;
            let totalUsersFetched = 0;
            
            console.log(`🔍 Starting to fetch users from Supabase auth...`);
            console.log(`📊 Found ${existingWallets.size} existing wallets to skip`);
            
            while (true) {
                console.log(`📄 Fetching page ${page} (per_page=${perPage})...`);
                
                const { data: users, error } = await this.supabase.auth.admin.listUsers({
                    page: page,
                    perPage: perPage
                });
                
                if (error) {
                    console.log(`Error fetching users: ${error.message}`);
                    break;
                }
                
                if (!users || users.length === 0) {
                    console.log(`📄 Page ${page} returned no users, stopping pagination`);
                    break;
                }
                
                console.log(`📄 Page ${page} returned ${users.length} users`);
                totalUsersFetched += users.length;
                
                const usersBatch = [];
                for (const user of users) {
                    // Skip users who already have wallets
                    if (existingWallets.has(user.id)) {
                        this.skippedWallets += 1;
                        continue;
                    }
                    
                    usersBatch.push({
                        id: user.id,
                        auth_id: user.id,
                        created_at: user.created_at
                    });
                }
                
                console.log(`📄 Page ${page}: ${usersBatch.length} users need wallets (skipped ${users.length - usersBatch.length} with existing wallets)`);
                allUsers.push(...usersBatch);
                
                if (users.length < perPage) {
                    console.log(`📄 Page ${page} had fewer users than per_page, stopping pagination`);
                    break;
                }
                    
                page += 1;
            }
            
            console.log(`📊 Total users fetched from auth: ${totalUsersFetched}`);
            console.log(`📊 Users needing wallets: ${allUsers.length}`);
            console.log(`📊 Users skipped (already have wallets): ${this.skippedWallets}`);
            return allUsers;
            
        } catch (error) {
            console.log(`Error fetching users from Supabase auth: ${error.message}`);
            return [];
        }
    }

    async generateFlowWallet() {
        try {
            const flowBinary = await this.getFlowBinary();
            if (!flowBinary) {
                return null;
            }
            
            // First, generate a key pair
            const keyCmd = `${flowBinary} keys generate -o json`;
            const { stdout: keyOutput } = await execAsync(keyCmd, {
                cwd: this.flowDir,
                timeout: 60000
            });
            
            const keyData = JSON.parse(keyOutput.trim());
            const publicKey = keyData.public;
            
            // Now create an actual Flow account with the public key
            const accountCmd = `${flowBinary} accounts create --key ${publicKey} --network ${NETWORK} -o json`;
            const { stdout: accountOutput } = await execAsync(accountCmd, {
                cwd: this.flowDir,
                timeout: 60000
            });
            
            const accountData = JSON.parse(accountOutput.trim());
            const accountAddress = accountData.address;
            
            // Return the key data with the actual account address
            return {
                private: keyData.private,
                public: keyData.public,
                address: accountAddress
            };
            
        } catch (error) {
            console.log(`Error generating wallet: ${error.message}`);
            return null;
        }
    }

    async waitForTransactionSeal(txId) {
        try {
            const flowBinary = await this.getFlowBinary();
            if (!flowBinary) {
                return false;
            }
            
            const startTime = Date.now();
            while (Date.now() - startTime < TRANSACTION_TIMEOUT * 1000) {
                const cmd = `${flowBinary} transactions get ${txId} --network ${NETWORK} -o json`;
                const { stdout } = await execAsync(cmd, {
                    cwd: this.flowDir,
                    timeout: 30000
                });
                
                try {
                    const txData = JSON.parse(stdout.trim());
                    const status = txData.status;
                    if (status === "SEALED") {
                        return true;
                    } else if (status === "FAILED") {
                        console.log(`Transaction ${txId} failed`);
                        return false;
                    }
                } catch (parseError) {
                    // Continue waiting
                }
                
                await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds before checking again
            }
            
            console.log(`Transaction ${txId} timed out after ${TRANSACTION_TIMEOUT} seconds`);
            return false;
            
        } catch (error) {
            console.log(`Error waiting for transaction seal: ${error.message}`);
            return false;
        }
    }

    async processTransactionQueue() {
        if (this.processingTransaction || this.transactionQueue.length === 0) {
            return;
        }

        this.processingTransaction = true;
        
        while (this.transactionQueue.length > 0 && this.running) {
            const task = this.transactionQueue.shift();
            const { user, keyData } = task;
            const authId = user.auth_id;
            
            console.log(`💾 Processing database save for ${authId}`);
            
            // Save to database
            if (await this.saveWalletToDatabase(authId, keyData)) {
                this.databaseSaves += 1;
                this.walletsData[authId] = keyData;
                this.successfulWallets += 1;
                console.log(`✅ Successfully saved wallet for ${authId}: ${keyData.address}`);
            } else {
                console.log(`❌ Failed to save wallet to database for ${authId}`);
            }
        }
        
        this.processingTransaction = false;
    }

    async savePrivateKey(authId, privateKey) {
        const accountsDir = path.join(this.flowDir, 'accounts');
        await fs.mkdir(accountsDir, { recursive: true });
        
        const pkeyFile = path.join(accountsDir, `${authId}.pkey`);
        await fs.writeFile(pkeyFile, privateKey);
        
        console.log(`✓ Saved private key: ${pkeyFile}`);
    }

    async saveWalletToDatabase(authId, keyData) {
        try {
            const walletData = {
                id: uuidv4(),
                created_at: new Date().toISOString(),
                auth_id: authId,
                flow_address: keyData.address,
                flow_private_key: keyData.private,
                flow_public_key: keyData.public
            };
            
            const { data, error } = await this.supabase
                .from('wallet')
                .insert(walletData);
            
            if (error) {
                console.log(`Error saving wallet to database for user ${authId}: ${error.message}`);
                return false;
            }
            
            return !!data;
                
        } catch (error) {
            console.log(`Error saving wallet to database for user ${authId}: ${error.message}`);
            return false;
        }
    }

    async createFlowProductionConfig() {
        const accountsDir = path.join(this.flowDir, 'accounts');
        await fs.mkdir(accountsDir, { recursive: true });
        
        const productionConfig = {
            accounts: {}
        };
        
        for (const [authId, walletData] of Object.entries(this.walletsData)) {
            productionConfig.accounts[authId] = {
                address: walletData.address,
                key: {
                    type: "file",
                    location: `${authId}.pkey`,
                    signatureAlgorithm: "ECDSA_secp256k1",
                    hashAlgorithm: "SHA2_256"
                }
            };
        }
        
        // Write flow-production.json
        const productionFile = path.join(accountsDir, 'flow-production.json');
        await fs.writeFile(productionFile, JSON.stringify(productionConfig, null, 4));
        
        console.log(`✓ Created flow-production.json with ${Object.keys(productionConfig.accounts).length} accounts`);
        return productionFile;
    }

    async processUserWallet(user) {
        const authId = user.auth_id;
        
        // Add rate limiting delay
        await new Promise(resolve => setTimeout(resolve, RATE_LIMIT_DELAY * 1000));
        
        console.log(`🔑 Generating wallet for ${authId}`);
        
        // Generate Flow wallet (sequential processing avoids sequence conflicts)
        const keyData = await this.generateFlowWallet();
        
        if (keyData) {
            console.log(`✅ Generated wallet for ${authId}: ${keyData.address}`);
            
            // Save private key immediately
            await this.savePrivateKey(authId, keyData.private);
            
            // Queue the database save for sequential processing
            this.transactionQueue.push({ user, keyData });
            
            return true;
        } else {
            console.log(`❌ Failed to generate wallet for ${authId}`);
            return false;
        }
    }

    async run() {
        console.log("🚀 Starting Flow wallet generation for all users...");
        console.log("Wallet generation will be processed sequentially to avoid Flow sequence number conflicts");
        console.log("Database saves will be processed sequentially to avoid conflicts");
        
        // Ensure we're in the right directory
        const fs = require('fs');
        if (!fs.existsSync(this.flowDir)) {
            console.log("Error: flow directory not found. Please run this script from the project root.");
            process.exit(1);
        }
        
        // Initialize Supabase client
        this.supabase = await this.getSupabaseClient();
        if (!this.supabase) {
            console.log("Error: Could not initialize Supabase client.");
            console.log("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.");
            process.exit(1);
        }
        
        // Check if Flow CLI is available
        if (!(await this.getFlowBinary())) {
            console.log("Error: Flow CLI not found. Please install Flow CLI.");
            process.exit(1);
        }
        
        // Get all users (excluding those with existing wallets)
        const users = await this.getAllUsers();
        if (!users || users.length === 0) {
            console.log("No users found that need wallets.");
            process.exit(0);
        }
        
        console.log(`📊 Processing ${users.length} users...`);
        
        // Process users sequentially to avoid Flow sequence number conflicts
        for (const user of users) {
            if (!this.running) {
                break;
            }
                
            try {
                await this.processUserWallet(user);
            } catch (error) {
                console.log(`❌ Error processing user ${user.auth_id}: ${error.message}`);
            }
        }
        
        // Wait for all queued database saves to complete
        if (this.successfulWallets > 0) {
            console.log(`⏳ Waiting for ${this.successfulWallets} database saves to complete...`);
            await this.processTransactionQueue();
        }
        
        console.log(`\n🎉 Summary:`);
        console.log(`- Processed: ${users.length} users`);
        console.log(`- Skipped: ${this.skippedWallets} users (already had wallets)`);
        console.log(`- Generated: ${this.successfulWallets} wallets`);
        console.log(`- Saved to database: ${this.databaseSaves} wallets`);
        
        if (this.successfulWallets > 0) {
            // Create flow-production.json
            const productionFile = await this.createFlowProductionConfig();
            console.log(`- Configuration saved to ${productionFile}`);
            
            // Show first few wallets as example
            console.log(`\nFirst 3 wallets:`);
            const walletEntries = Object.entries(this.walletsData);
            for (let i = 0; i < Math.min(3, walletEntries.length); i++) {
                const [authId, data] = walletEntries[i];
                console.log(`  ${authId}: ${data.address}`);
            }
        } else {
            console.log("No wallets were generated successfully.");
            process.exit(1);
        }
    }
}

async function main() {
    const generator = new FlowWalletGenerator();
    await generator.run();
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = { FlowWalletGenerator };
