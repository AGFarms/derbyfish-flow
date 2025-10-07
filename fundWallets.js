#!/usr/bin/env node
/**
 * Flow Wallet Funding Daemon
 *
 * This daemon monitors and funds Flow wallets to maintain a 0.1 FLOW balance:
 * 1. Fetches all users from Supabase auth
 * 2. Checks each user's Flow balance
 * 3. Funds wallets that have less than 0.1 FLOW
 * 4. Runs as a daemon, checking every hour
 *
 * Usage:
 *    node fundWallets.js
 */

const { createClient } = require('@supabase/supabase-js');
const { config } = require('dotenv');
const { FlowWrapper } = require('./flowWrapper');
const cron = require('node-cron');
const { performance } = require('perf_hooks');

// Load environment variables from .env file
config();

// Configuration
const TARGET_BALANCE = 0.1; // FLOW
const FUNDING_AMOUNT = 0.1; // FLOW to send when funding
const CHECK_INTERVAL = 3600; // 1 hour in seconds
const FUNDER_ACCOUNT = "mainnet-agfarms"; // Account that funds other wallets
const NETWORK = "mainnet";
const TRANSACTION_TIMEOUT = 300; // 5 minutes timeout for transaction sealing
const RATE_LIMIT_DELAY = 1.0; // Delay between requests to avoid rate limiting
const BALANCE_CHECK_THREADS = 8; // Number of threads for balance checking

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

class FlowWalletDaemon {
    constructor() {
        this.running = true;
        this.supabase = null;
        this.flowDir = './flow';
        this.transactionQueue = [];
        this.processingTransaction = false;
        
        // Initialize Flow wrapper
        this.flowWrapper = new FlowWrapper({
            network: 'mainnet',
            flowDir: this.flowDir,
            timeout: 60,
            maxRetries: 3,
            rateLimitDelay: 0.02, // 20ms for 50 RPS limit
            jsonOutput: true
        });
        
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

    getFlowBinary() {
        return this.flowWrapper.flowBinary;
    }

    async getAllWallets() {
        try {
            const allWallets = [];
            let page = 1;
            const perPage = 1000;
            
            while (true) {
                const { data, error } = await this.supabase
                    .from('wallet')
                    .select('*')
                    .range((page - 1) * perPage, page * perPage - 1);
                
                if (error) {
                    console.log(`Error fetching wallets: ${error.message}`);
                    break;
                }
                
                if (!data || data.length === 0) {
                    break;
                }
                
                allWallets.push(...data);
                
                if (data.length < perPage) {
                    break;
                }
                    
                page += 1;
            }
            
            return allWallets;
            
        } catch (error) {
            console.log(`Error fetching wallets from database: ${error.message}`);
            return [];
        }
    }

    async checkFlowBalance(address) {
        try {
            // Use Flow wrapper to execute script
            const result = await this.flowWrapper.executeScript(
                "cadence/scripts/checkFlowBalance.cdc",
                [address],
                30
            );
            
            if (!result.success) {
                // Check if it's a rate limit error
                if (result.errorMessage.toLowerCase().includes("rate limited")) {
                    console.log(`⚠️  Rate limited for ${address}, will retry later`);
                    return null;
                }
                console.log(`Error checking balance for ${address}: ${result.errorMessage}`);
                return null;
            }
            
            // Parse the JSON result
            try {
                const balanceData = result.data;
                
                // The script returns a dictionary with a "value" array containing key-value pairs
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
                    console.log(`FLOW_Balance not found in response for ${address}`);
                    return 0.0;
                } else {
                    console.log(`Unexpected response format for ${address}: ${JSON.stringify(balanceData)}`);
                    return null;
                }
                    
            } catch (parseError) {
                console.log(`Error parsing balance result for ${address}: ${parseError.message}`);
                return null;
            }
            
        } catch (error) {
            console.log(`Error checking Flow balance for ${address}: ${error.message}`);
            return null;
        }
    }

    async waitForTransactionSeal(txId) {
        try {
            // Use Flow wrapper to wait for transaction seal
            const result = await this.flowWrapper.waitForTransactionSeal(txId, TRANSACTION_TIMEOUT);
            return result.success;
            
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
            const { wallet, needed, fundingAmount } = task;
            const authId = wallet.auth_id;
            const flowAddress = wallet.flow_address;
            
            console.log(`💸 Processing funding for ${authId} - sending ${fundingAmount} FLOW`);
            
            // Fund the wallet
            if (await this.fundWallet(flowAddress, fundingAmount)) {
                // Wait a moment for the transaction to propagate
                await new Promise(resolve => setTimeout(resolve, 3000));
                
                // Verify the balance after funding
                const newBalance = await this.checkFlowBalance(flowAddress);
                if (newBalance !== null) {
                    const balanceIncrease = newBalance - (newBalance - fundingAmount);
                    console.log(`✅ Successfully funded ${authId} - Balance increased by ${balanceIncrease.toFixed(6)} FLOW (new balance: ${newBalance.toFixed(6)} FLOW)`);
                } else {
                    console.log(`⚠️  Funded ${authId} but could not verify new balance`);
                }
            } else {
                console.log(`❌ Failed to fund ${authId}`);
            }
        }
        
        this.processingTransaction = false;
    }

    async fundWallet(toAddress, amount) {
        try {
            // Use Flow wrapper to send transaction
            const result = await this.flowWrapper.sendTransaction(
                "cadence/transactions/fundWallet.cdc",
                [`0x${toAddress}`, amount.toString()],
                { signer: FUNDER_ACCOUNT },
                60
            );
            
            if (!result.success) {
                // Check for sequence number errors
                if (result.errorMessage.toLowerCase().includes("sequence number")) {
                    console.log(`⚠️  Sequence number error for ${toAddress}, will retry later`);
                    return false;
                }
                console.log(`Error funding wallet ${toAddress}: ${result.errorMessage}`);
                return false;
            }
            
            if (!result.transactionId) {
                console.log(`Could not extract transaction ID for ${toAddress}`);
                return false;
            }
            
            console.log(`🔄 Transaction ${result.transactionId} sent for ${toAddress}, waiting for seal...`);
            
            // Wait for transaction to seal
            if (!(await this.waitForTransactionSeal(result.transactionId))) {
                return false;
            }
            
            console.log(`✓ Transaction ${result.transactionId} sealed for ${toAddress}`);
            return true;
            
        } catch (error) {
            console.log(`Error funding wallet ${toAddress}: ${error.message}`);
            return false;
        }
    }

    async processWallet(wallet) {
        const authId = wallet.auth_id;
        const flowAddress = wallet.flow_address;
        
        // Add rate limiting delay
        await new Promise(resolve => setTimeout(resolve, RATE_LIMIT_DELAY * 1000));
        
        console.log(`🔍 Checking balance for ${authId} (${flowAddress})`);
        
        // Check current balance
        const balance = await this.checkFlowBalance(flowAddress);
        if (balance === null) {
            console.log(`❌ Could not check balance for ${authId}`);
            return { success: false, queuedForFunding: false };
        }
        
        console.log(`💰 Current balance: ${balance} FLOW`);
        
        // Check if funding is needed
        if (balance < TARGET_BALANCE) {
            const needed = TARGET_BALANCE - balance;
            const fundingAmount = Math.min(needed, FUNDING_AMOUNT);
            
            console.log(`📝 Queueing funding for ${authId} - needed: ${needed} FLOW, sending: ${fundingAmount} FLOW`);
            
            // Queue the funding task for sequential processing
            this.transactionQueue.push({ wallet, needed, fundingAmount });
            return { success: true, queuedForFunding: true };
        } else {
            console.log(`✅ ${authId} has sufficient balance (${balance} FLOW)`);
            return { success: true, queuedForFunding: false };
        }
    }

    async runCycle() {
        console.log(`\n🔄 Starting funding cycle at ${new Date().toISOString()}`);
        
        // Get all wallets
        const wallets = await this.getAllWallets();
        if (!wallets || wallets.length === 0) {
            console.log("No wallets found in database.");
            return;
        }
        
        console.log(`📊 Processing ${wallets.length} wallets with ${BALANCE_CHECK_THREADS} threads for balance checking...`);
        
        let successfulChecks = 0;
        let queuedFundings = 0;
        let totalProcessed = 0;
        const failedWallets = [];
        
        // Process wallets in parallel for balance checking
        const processPromises = [];
        const concurrencyLimit = BALANCE_CHECK_THREADS;
        
        for (let i = 0; i < wallets.length; i += concurrencyLimit) {
            const batch = wallets.slice(i, i + concurrencyLimit);
            const batchPromises = batch.map(async (wallet) => {
                if (!this.running) {
                    return { success: false, queuedForFunding: false };
                }
                
                try {
                    return await this.processWallet(wallet);
                } catch (error) {
                    console.log(`❌ Error processing wallet ${wallet.auth_id}: ${error.message}`);
                    return { success: false, queuedForFunding: false };
                }
            });
            
            processPromises.push(...batchPromises);
        }
        
        // Process all wallets
        const results = await Promise.all(processPromises);
        
        // Process results
        for (let i = 0; i < results.length; i++) {
            const result = results[i];
            const wallet = wallets[i];
            
            if (result.success) {
                successfulChecks += 1;
                if (result.queuedForFunding) {
                    queuedFundings += 1;
                }
            } else {
                failedWallets.push(wallet.auth_id);
            }
            totalProcessed += 1;
            
            console.log(`📊 Progress: ${totalProcessed}/${wallets.length} wallets processed`);
        }
        
        // Process queued transactions
        if (queuedFundings > 0) {
            console.log(`⏳ Processing ${queuedFundings} funding transactions...`);
            await this.processTransactionQueue();
        }
        
        console.log(`\n📈 Cycle Summary:`);
        console.log(`- Processed: ${totalProcessed} wallets`);
        console.log(`- Successful checks: ${successfulChecks} wallets`);
        console.log(`- Queued for funding: ${queuedFundings} wallets`);
        if (failedWallets.length > 0) {
            console.log(`- Failed wallets: ${failedWallets.length}`);
            console.log(`- Failed wallet IDs: ${failedWallets.slice(0, 10).join(', ')}${failedWallets.length > 10 ? '...' : ''}`);
        }
        
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
        
        console.log(`- Next check in ${CHECK_INTERVAL} seconds`);
    }

    async run() {
        console.log("🚀 Starting Flow Wallet Funding Daemon...");
        console.log(`Target balance: ${TARGET_BALANCE} FLOW`);
        console.log(`Funding amount: ${FUNDING_AMOUNT} FLOW`);
        console.log(`Check interval: ${CHECK_INTERVAL} seconds`);
        console.log(`Transaction timeout: ${TRANSACTION_TIMEOUT} seconds`);
        console.log(`Funder account: ${FUNDER_ACCOUNT}`);
        console.log(`Network: ${NETWORK}`);
        console.log(`Balance checking: ${BALANCE_CHECK_THREADS} threads (parallel)`);
        console.log("Transactions: Sequential (1 at a time to avoid sequence number conflicts)");
        
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
        if (!this.getFlowBinary()) {
            console.log("Error: Flow CLI not found. Please install Flow CLI.");
            process.exit(1);
        }
        
        console.log("✅ Daemon initialized successfully");
        
        // Main daemon loop
        while (this.running) {
            try {
                await this.runCycle();
                
                if (this.running) {
                    console.log(`⏰ Waiting ${CHECK_INTERVAL} seconds until next check...`);
                    await new Promise(resolve => setTimeout(resolve, CHECK_INTERVAL * 1000));
                }
                    
            } catch (error) {
                console.log(`❌ Error in daemon loop: ${error.message}`);
                console.log("⏰ Waiting 60 seconds before retrying...");
                await new Promise(resolve => setTimeout(resolve, 60000));
            }
        }
        
        console.log("👋 Daemon stopped");
    }
}

async function main() {
    const daemon = new FlowWalletDaemon();
    await daemon.run();
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = { FlowWalletDaemon };
