const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');
const { performance } = require('perf_hooks');

const execAsync = promisify(exec);

class FlowOperationType {
    static SCRIPT = "script";
    static TRANSACTION = "transaction";
    static ACCOUNT = "account";
    static BLOCK = "block";
}

class FlowNetwork {
    static MAINNET = "mainnet";
    static TESTNET = "testnet";
    static EMULATOR = "emulator";
}

class FlowResult {
    constructor(options = {}) {
        this.success = options.success || false;
        this.data = options.data || null;
        this.rawOutput = options.rawOutput || "";
        this.errorMessage = options.errorMessage || "";
        this.executionTime = options.executionTime || 0.0;
        this.command = options.command || "";
        this.network = options.network || "";
        this.operationType = options.operationType || "";
        this.transactionId = options.transactionId || null;
        this.retryCount = options.retryCount || 0;
    }

    toDict() {
        return {
            success: this.success,
            data: this.data,
            rawOutput: this.rawOutput,
            errorMessage: this.errorMessage,
            executionTime: this.executionTime,
            command: this.command,
            network: this.network,
            operationType: this.operationType,
            transactionId: this.transactionId,
            retryCount: this.retryCount
        };
    }
}

class FlowConfig {
    constructor(options = {}) {
        this.network = options.network || FlowNetwork.MAINNET;
        this.flowDir = options.flowDir || path.join(process.cwd(), "flow");
        this.timeout = options.timeout || 300; // 5 minutes
        this.maxRetries = options.maxRetries || 3;
        this.retryDelay = options.retryDelay || 1.0;
        this.rateLimitDelay = options.rateLimitDelay || 0.2; // 200ms between requests
        this.jsonOutput = options.jsonOutput !== false; // Default true
        this.logLevel = options.logLevel || "INFO";
    }
}

class FlowRateLimiter {
    constructor(delay = 0.2) {
        this.delay = delay;
        this.lastRequestTime = 0;
        this.lock = false;
    }

    async waitIfNeeded() {
        if (this.lock) {
            // Wait for lock to be released
            while (this.lock) {
                await new Promise(resolve => setTimeout(resolve, 10));
            }
        }

        this.lock = true;
        try {
            const currentTime = performance.now() / 1000;
            const timeSinceLast = currentTime - this.lastRequestTime;
            
            if (timeSinceLast < this.delay) {
                const sleepTime = (this.delay - timeSinceLast) * 1000;
                console.debug(`Rate limiting: sleeping ${sleepTime.toFixed(3)}s`);
                await new Promise(resolve => setTimeout(resolve, sleepTime));
            }
            
            this.lastRequestTime = performance.now() / 1000;
        } finally {
            this.lock = false;
        }
    }
}

class FlowMetrics {
    constructor() {
        this.lock = false;
        this.reset();
    }

    reset() {
        this.lock = true;
        try {
            this.totalOperations = 0;
            this.successfulOperations = 0;
            this.failedOperations = 0;
            this.totalExecutionTime = 0.0;
            this.retryCount = 0;
            this.rateLimitedOperations = 0;
            this.timeoutOperations = 0;
            this.operationTypes = {};
            this.networks = {};
        } finally {
            this.lock = false;
        }
    }

    async recordOperation(result) {
        while (this.lock) {
            await new Promise(resolve => setTimeout(resolve, 10));
        }

        this.lock = true;
        try {
            this.totalOperations += 1;
            this.totalExecutionTime += result.executionTime;
            this.retryCount += result.retryCount;
            
            // Count by operation type
            const opType = result.operationType;
            if (!this.operationTypes[opType]) {
                this.operationTypes[opType] = { total: 0, success: 0, failed: 0 };
            }
            this.operationTypes[opType].total += 1;
            
            // Count by network
            const network = result.network;
            if (!this.networks[network]) {
                this.networks[network] = { total: 0, success: 0, failed: 0 };
            }
            this.networks[network].total += 1;
            
            if (result.success) {
                this.successfulOperations += 1;
                this.operationTypes[opType].success += 1;
                this.networks[network].success += 1;
            } else {
                this.failedOperations += 1;
                this.operationTypes[opType].failed += 1;
                this.networks[network].failed += 1;
                
                // Categorize failures
                if (result.errorMessage.toLowerCase().includes("rate limited")) {
                    this.rateLimitedOperations += 1;
                }
                if (result.errorMessage.toLowerCase().includes("timeout")) {
                    this.timeoutOperations += 1;
                }
            }
        } finally {
            this.lock = false;
        }
    }

    getSummary() {
        while (this.lock) {
            // Wait for lock to be released
        }

        this.lock = true;
        try {
            const avgExecutionTime = this.totalOperations > 0 
                ? this.totalExecutionTime / this.totalOperations 
                : 0.0;
            const successRate = this.totalOperations > 0 
                ? (this.successfulOperations / this.totalOperations) * 100 
                : 0.0;
            
            return {
                total_operations: this.totalOperations,
                successful_operations: this.successfulOperations,
                failed_operations: this.failedOperations,
                success_rate_percent: Math.round(successRate * 100) / 100,
                average_execution_time: Math.round(avgExecutionTime * 1000) / 1000,
                total_retries: this.retryCount,
                rate_limited_operations: this.rateLimitedOperations,
                timeout_operations: this.timeoutOperations,
                operation_types: { ...this.operationTypes },
                networks: { ...this.networks }
            };
        } finally {
            this.lock = false;
        }
    }
}

class FlowWrapper {
    constructor(config = {}) {
        this.config = new FlowConfig(config);
        this.rateLimiter = new FlowRateLimiter(this.config.rateLimitDelay);
        this.metrics = new FlowMetrics();
        this.flowBinary = null;
        this.initializeFlowBinary();
    }

    async initializeFlowBinary() {
        try {
            const { stdout } = await execAsync('which flow');
            this.flowBinary = stdout.trim();
            console.log(`Flow CLI binary found: ${this.flowBinary}`);
        } catch (error) {
            console.error(`Failed to find Flow CLI binary: ${error.message}`);
            throw new Error("Flow CLI not found in PATH");
        }
    }

    buildBaseCommand(operation, args = []) {
        if (!this.flowBinary) {
            throw new Error("Flow CLI binary not initialized");
        }
        
        const cmd = [this.flowBinary, ...operation.split(' ')];
        if (args.length > 0) {
            cmd.push(...args);
        }
        
        // Add configuration files - both flow.json and flow-production.json
        // Since we run from flow/ directory, paths are relative to that
        cmd.push('-f', 'flow.json');
        cmd.push('-f', 'accounts/flow-production.json');
        
        // Add network if not already specified
        if (!cmd.includes('--network') && !cmd.includes('--net')) {
            cmd.push('--network', this.config.network);
        }
        
        // Add JSON output for scripts and transactions
        if ((operation.startsWith('scripts') || operation.startsWith('transactions')) && this.config.jsonOutput) {
            if (!cmd.includes('--output') && !cmd.includes('-o')) {
                cmd.push('--output', 'json');
            }
        }
        
        return cmd;
    }

    async executeCommand(cmd, timeout = null) {
        const startTime = performance.now();
        const actualTimeout = timeout || this.config.timeout;
        const cmdStr = cmd.join(' ');
        
        // COMPREHENSIVE DEBUG OUTPUT
        console.log("=".repeat(80));
        console.log("🔍 FLOWWRAPPER DEBUG - SUBPROCESS EXECUTION");
        console.log("=".repeat(80));
        console.log(`📋 Command array: ${JSON.stringify(cmd)}`);
        console.log(`📋 Command string: ${cmdStr}`);
        console.log(`📋 Command length: ${cmd.length}`);
        console.log(`📋 Contains '--signer': ${cmd.includes('--signer')}`);
        console.log(`📋 Contains '--proposer': ${cmd.includes('--proposer')}`);
        console.log(`📋 Contains '--authorizer': ${cmd.includes('--authorizer')}`);
        console.log(`📋 Contains '--payer': ${cmd.includes('--payer')}`);
        console.log();
        
        // Environment debugging
        console.log("🌍 ENVIRONMENT DEBUG:");
        console.log(`   Current working directory: ${process.cwd()}`);
        console.log(`   Flow directory (cwd): ${this.config.flowDir}`);
        console.log(`   Flow directory exists: ${require('fs').existsSync(this.config.flowDir)}`);
        console.log(`   Flow directory absolute: ${path.resolve(this.config.flowDir)}`);
        console.log(`   Node.js version: ${process.version}`);
        console.log(`   Process ID: ${process.pid}`);
        console.log(`   Parent process ID: ${process.ppid}`);
        console.log();
        
        // File system debugging
        console.log("📁 FILE SYSTEM DEBUG:");
        try {
            const flowDirContents = await fs.readdir(this.config.flowDir);
            console.log(`   Flow directory contents: ${flowDirContents}`);
            console.log(`   flow.json exists: ${require('fs').existsSync(path.join(this.config.flowDir, 'flow.json'))}`);
            console.log(`   flow-production.json exists: ${require('fs').existsSync(path.join(this.config.flowDir, 'accounts', 'flow-production.json'))}`);
        } catch (error) {
            console.log(`   Error listing flow directory: ${error.message}`);
        }
        console.log();
        
        // Flow CLI debugging
        console.log("⚡ FLOW CLI DEBUG:");
        console.log(`   Flow binary: ${this.flowBinary}`);
        console.log(`   Flow binary exists: ${require('fs').existsSync(this.flowBinary)}`);
        try {
            // Test flow version
            const { stdout } = await execAsync(`${this.flowBinary} version`, {
                cwd: this.config.flowDir,
                timeout: 5000
            });
            console.log(`   Flow version: ${stdout.trim()}`);
            console.log(`   Flow version command success: true`);
        } catch (error) {
            console.log(`   Error getting Flow version: ${error.message}`);
        }
        console.log();
        
        console.debug(`Executing Flow command: ${cmdStr}`);
        console.log(`🚀 EXECUTING FLOW COMMAND: ${cmdStr}`);
        
        try {
            // Apply rate limiting
            await this.rateLimiter.waitIfNeeded();
            
            // Execute command from the flow directory
            console.log(`🎯 About to execute subprocess.run with:`);
            console.log(`   cmd: ${JSON.stringify(cmd)}`);
            console.log(`   cwd: ${this.config.flowDir}`);
            console.log(`   timeout: ${actualTimeout}`);
            console.log("=".repeat(80));
            
            const { stdout, stderr } = await execAsync(cmdStr, {
                cwd: this.config.flowDir,
                timeout: actualTimeout * 1000, // Convert to milliseconds
                shell: false,
                env: process.env
            });
            
            const executionTime = (performance.now() - startTime) / 1000;
            
            // SUBPROCESS RESULT DEBUG
            console.log("📊 SUBPROCESS RESULT DEBUG:");
            console.log(`   Return code: 0`);
            console.log(`   Execution time: ${executionTime.toFixed(3)}s`);
            console.log(`   STDOUT length: ${stdout.length}`);
            console.log(`   STDERR length: ${stderr.length}`);
            console.log(`   STDOUT preview: ${stdout.substring(0, 200)}...`);
            console.log(`   STDERR preview: ${stderr.substring(0, 200)}...`);
            console.log();
            
            // Parse output
            let data = null;
            if (stdout.trim()) {
                try {
                    data = JSON.parse(stdout.trim());
                    console.log("✅ Successfully parsed JSON output");
                } catch (jsonError) {
                    // Not JSON output, use raw text
                    data = { raw_output: stdout.trim() };
                    console.log("⚠️  Could not parse JSON, using raw output");
                }
            }
            
            // Extract transaction ID if present
            let transactionId = null;
            if (stdout && stdout.includes('Transaction ID:')) {
                const lines = stdout.split('\n');
                for (const line of lines) {
                    if (line.includes('Transaction ID:')) {
                        const parts = line.split(':');
                        if (parts.length > 1) {
                            transactionId = parts[1].trim();
                            break;
                        }
                    }
                }
            }
            
            const flowResult = new FlowResult({
                success: true,
                data: data,
                rawOutput: stdout,
                errorMessage: stderr,
                executionTime: executionTime,
                command: cmdStr,
                network: this.config.network,
                operationType: this.determineOperationType(cmd),
                transactionId: transactionId
            });
            
            // Record metrics
            await this.metrics.recordOperation(flowResult);
            
            console.log("🎯 FINAL RESULT:");
            console.log(`   Success: ${flowResult.success}`);
            console.log(`   Transaction ID: ${flowResult.transactionId}`);
            console.log(`   Error message: ${flowResult.errorMessage}`);
            console.log("=".repeat(80));
            
            if (flowResult.success) {
                console.debug(`Flow command succeeded in ${executionTime.toFixed(3)}s`);
            } else {
                console.warn(`Flow command failed: ${stderr}`);
            }
            
            return flowResult;
            
        } catch (error) {
            const executionTime = (performance.now() - startTime) / 1000;
            let errorMsg;
            
            if (error.code === 'TIMEOUT') {
                errorMsg = `Command timed out after ${actualTimeout} seconds`;
                console.error(`Flow command timeout: ${cmdStr}`);
            } else {
                errorMsg = `Unexpected error: ${error.message}`;
                console.error(`Flow command error: ${cmdStr} - ${errorMsg}`);
            }
            
            const flowResult = new FlowResult({
                success: false,
                errorMessage: errorMsg,
                executionTime: executionTime,
                command: cmdStr,
                network: this.config.network,
                operationType: this.determineOperationType(cmd)
            });
            
            await this.metrics.recordOperation(flowResult);
            return flowResult;
        }
    }

    determineOperationType(cmd) {
        const cmdStr = cmd.join(' ').toLowerCase();
        if (cmdStr.includes('scripts')) {
            return FlowOperationType.SCRIPT;
        } else if (cmdStr.includes('transactions')) {
            return FlowOperationType.TRANSACTION;
        } else if (cmdStr.includes('accounts')) {
            return FlowOperationType.ACCOUNT;
        } else if (cmdStr.includes('blocks')) {
            return FlowOperationType.BLOCK;
        } else {
            return "unknown";
        }
    }

    async retryOperation(operationFunc, ...args) {
        let lastResult = null;
        
        for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
            if (attempt > 0) {
                const delay = this.config.retryDelay * Math.pow(2, attempt - 1);
                console.log(`Retrying operation (attempt ${attempt + 1}/${this.config.maxRetries + 1}) after ${delay}s`);
                await new Promise(resolve => setTimeout(resolve, delay * 1000));
            }
            
            const result = await operationFunc(...args);
            result.retryCount = attempt;
            
            if (result.success) {
                return result;
            }
            
            lastResult = result;
            
            // Don't retry on certain errors
            const nonRetryableErrors = ['invalid', 'not found', 'unauthorized', 'insufficient'];
            if (nonRetryableErrors.some(error => result.errorMessage.toLowerCase().includes(error))) {
                console.warn(`Non-retryable error: ${result.errorMessage}`);
                break;
            }
        }
        
        return lastResult;
    }

    async executeScript(scriptPath, args = [], timeout = null) {
        const execute = async () => {
            const cmd = this.buildBaseCommand(`scripts execute ${scriptPath}`, args);
            return await this.executeCommand(cmd, timeout);
        };
        
        return await this.retryOperation(execute);
    }

    async sendTransaction(transactionPath, args = [], roles = {}, timeout = null) {
        const execute = async () => {
            const cmd = this.buildBaseCommand(`transactions send ${transactionPath}`, args);
            
            // Always use individual role flags: --proposer, --authorizer, --payer
            // Never use --signer flag
            // Always hardcode proposer to mainnet-agfarms
            
            cmd.push('--proposer', 'mainnet-agfarms'); // Always hardcode proposer
            
            // Handle authorizers - always include mainnet-agfarms and any additional authorizers
            let authorizerList = ['mainnet-agfarms']; // Always include mainnet-agfarms
            if (roles.authorizers) {
                authorizerList.push(...roles.authorizers);
            } else if (roles.authorizer) {
                authorizerList.push(roles.authorizer);
            }
            
            // Add authorizers as comma-separated list
            const authorizerString = authorizerList.join(',');
            cmd.push('--authorizer', authorizerString);
            
            if (roles.payer) {
                cmd.push('--payer', roles.payer);
            }
            
            return await this.executeCommand(cmd, timeout);
        };
        
        return await this.retryOperation(execute);
    }

    async getAccount(address, timeout = null) {
        const execute = async () => {
            const cmd = this.buildBaseCommand(`accounts get ${address}`);
            return await this.executeCommand(cmd, timeout);
        };
        
        return await this.retryOperation(execute);
    }

    async getTransaction(transactionId, timeout = null) {
        const execute = async () => {
            const cmd = this.buildBaseCommand(`transactions get ${transactionId}`);
            return await this.executeCommand(cmd, timeout);
        };
        
        return await this.retryOperation(execute);
    }

    async waitForTransactionSeal(transactionId, timeout = 300) {
        const startTime = performance.now();
        
        while ((performance.now() - startTime) / 1000 < timeout) {
            const result = await this.getTransaction(transactionId);
            
            if (result.success && result.data) {
                const status = result.data.status?.toUpperCase();
                if (status === 'SEALED') {
                    console.log(`Transaction ${transactionId} sealed successfully`);
                    return result;
                } else if (status === 'FAILED') {
                    console.error(`Transaction ${transactionId} failed`);
                    return new FlowResult({
                        success: false,
                        errorMessage: `Transaction ${transactionId} failed`,
                        command: `transactions get ${transactionId}`,
                        network: this.config.network,
                        operationType: FlowOperationType.TRANSACTION
                    });
                }
            }
            
            await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds before checking again
        }
        
        // Timeout
        return new FlowResult({
            success: false,
            errorMessage: `Transaction ${transactionId} did not seal within ${timeout} seconds`,
            command: `transactions get ${transactionId}`,
            network: this.config.network,
            operationType: FlowOperationType.TRANSACTION
        });
    }

    getMetrics() {
        return this.metrics.getSummary();
    }

    resetMetrics() {
        this.metrics.reset();
    }

    updateConfig(options) {
        for (const [key, value] of Object.entries(options)) {
            if (this.config.hasOwnProperty(key)) {
                this.config[key] = value;
                console.log(`Updated config: ${key} = ${value}`);
            }
        }
    }
}

// Convenience functions for common operations
function createFlowWrapper(network = "mainnet", options = {}) {
    const config = new FlowConfig({
        network: network,
        ...options
    });
    return new FlowWrapper(config);
}

async function executeScript(scriptPath, args = [], network = "mainnet", options = {}) {
    const wrapper = createFlowWrapper(network, options);
    return await wrapper.executeScript(scriptPath, args);
}

async function sendTransaction(transactionPath, args = [], network = "mainnet", options = {}) {
    const wrapper = createFlowWrapper(network, options);
    return await wrapper.sendTransaction(transactionPath, args, options);
}

module.exports = {
    FlowWrapper,
    FlowConfig,
    FlowResult,
    FlowNetwork,
    FlowOperationType,
    createFlowWrapper,
    executeScript,
    sendTransaction
};
