"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FlowWrapper = exports.FlowConfig = exports.FlowResult = void 0;
exports.createFlowWrapper = createFlowWrapper;
exports.executeScript = executeScript;
exports.sendTransaction = sendTransaction;
const promises_1 = __importDefault(require("fs/promises"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const elliptic_1 = require("elliptic");
const crypto_1 = __importDefault(require("crypto"));
const fcl = __importStar(require("@onflow/fcl"));
const types_1 = require("./types");
const supabase_1 = require("./supabase");
class FlowResult {
    constructor(options = {}) {
        this.success = options.success || false;
        this.data = options.data || null;
        this.errorMessage = options.errorMessage || "";
        this.transactionId = options.transactionId || null;
    }
    toDict() {
        return {
            success: this.success,
            data: this.data,
            errorMessage: this.errorMessage,
            transactionId: this.transactionId
        };
    }
}
exports.FlowResult = FlowResult;
class FlowConfig {
    constructor(options = {}) {
        this.network = options.network || types_1.FlowNetwork.MAINNET;
        this.flowDir = options.flowDir || path_1.default.join(process.cwd(), 'flow');
    }
}
exports.FlowConfig = FlowConfig;
class FlowWrapper {
    constructor(config = {}) {
        this.config = new FlowConfig(config);
        fcl.config().put('accessNode.api', this.getAccessNode(this.config.network));
        const baitAddr = '0xed2202de80195438';
        const ftAddr = '0xf233dcee88fe0abe';
        fcl.config()
            .put('0xBaitCoin', baitAddr)
            .put('0xFungibleToken', ftAddr)
            .put('contracts.BaitCoin', baitAddr)
            .put('contracts.FungibleToken', ftAddr);
        this.loadFlowConfig();
        const svc = this.loadServiceAccount(this.config.flowDir);
        this.service = svc;
        console.log('=== CONSTRUCTOR SERVICE ACCOUNT SETUP ===');
        console.log(`Service address: ${svc.address}`);
        console.log(`Service key: ${svc.key ? 'LOADED' : 'NOT LOADED'}`);
        console.log(`Service keyId: ${svc.keyId}`);
        console.log(`Service signatureAlgorithm: ${svc.signatureAlgorithm}`);
        console.log(`Service hashAlgorithm: ${svc.hashAlgorithm}`);
        this.authz = svc.address && svc.key ? this.authzFactory(svc.address, svc.keyId || 0, svc.key, svc.signatureAlgorithm, svc.hashAlgorithm) : null;
        console.log(`Authz configured: ${this.authz ? 'YES' : 'NO'}`);
        console.log('==========================================');
    }
    getAccessNode(network) {
        if (network === types_1.FlowNetwork.MAINNET)
            return 'https://rest-mainnet.onflow.org';
        if (network === types_1.FlowNetwork.TESTNET)
            return 'https://rest-testnet.onflow.org';
        return 'http://127.0.0.1:8888';
    }
    loadFlowConfig() {
        const flowJsonPath = path_1.default.join(this.config.flowDir, 'flow.json');
        if (fs_1.default.existsSync(flowJsonPath)) {
            try {
                const flowConfig = JSON.parse(fs_1.default.readFileSync(flowJsonPath, 'utf8'));
                if (flowConfig.contracts) {
                    for (const [contractName, contractConfig] of Object.entries(flowConfig.contracts)) {
                        if (contractConfig.aliases && contractConfig.aliases[this.config.network]) {
                            const address = String(contractConfig.aliases[this.config.network]);
                            const withPrefix = address.startsWith('0x') ? address : `0x${address}`;
                            fcl.config().put(`0x${contractName}`, withPrefix);
                        }
                    }
                }
            }
            catch { }
        }
    }
    loadServiceAccount(flowDir) {
        console.log('=== LOADING SERVICE ACCOUNT ===');
        console.log(`Flow Directory: ${flowDir}`);
        const keyPath = path_1.default.join(flowDir, 'mainnet-agfarms.pkey');
        console.log(`Private key path: ${keyPath}`);
        console.log(`Private key file exists: ${fs_1.default.existsSync(keyPath)}`);
        const key = fs_1.default.existsSync(keyPath) ? fs_1.default.readFileSync(keyPath, 'utf8').trim() : null;
        console.log(`Private key loaded: ${key ? 'YES' : 'NO'}`);
        if (key) {
            console.log(`Private key length: ${key.length} characters`);
            console.log(`Private key preview: ${key.substring(0, 8)}...${key.substring(key.length - 8)}`);
        }
        let address = null;
        let keyId = 0;
        let signatureAlgorithm = 'ECDSA_secp256k1';
        let hashAlgorithm = 'SHA2_256';
        const flowJsonPath = path_1.default.join(flowDir, 'flow.json');
        console.log(`Flow.json path: ${flowJsonPath}`);
        console.log(`Flow.json exists: ${fs_1.default.existsSync(flowJsonPath)}`);
        if (fs_1.default.existsSync(flowJsonPath)) {
            try {
                const cfg = JSON.parse(fs_1.default.readFileSync(flowJsonPath, 'utf8'));
                console.log('Flow.json loaded successfully');
                console.log(`Accounts in flow.json: ${Object.keys(cfg.accounts || {}).join(', ')}`);
                if (cfg.accounts && cfg.accounts['mainnet-agfarms']) {
                    address = String(cfg.accounts['mainnet-agfarms'].address);
                    console.log(`Found mainnet-agfarms address in flow.json: ${address}`);
                    if (cfg.accounts['mainnet-agfarms'].key && typeof cfg.accounts['mainnet-agfarms'].key.index === 'number') {
                        keyId = cfg.accounts['mainnet-agfarms'].key.index;
                    }
                    if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm) {
                        signatureAlgorithm = cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm;
                    }
                    if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.hashAlgorithm) {
                        hashAlgorithm = cfg.accounts['mainnet-agfarms'].key.hashAlgorithm;
                    }
                    console.log(`Key configuration: keyId=${keyId}, sigAlg=${signatureAlgorithm}, hashAlg=${hashAlgorithm}`);
                }
                else {
                    console.log('mainnet-agfarms account not found in flow.json');
                }
            }
            catch (error) {
                console.log(`Error loading flow.json: ${error}`);
            }
        }
        if (!address) {
            console.log('Address not found in flow.json, checking flow-production.json...');
            const accountsPath = path_1.default.join(flowDir, 'accounts', 'flow-production.json');
            console.log(`Flow-production.json path: ${accountsPath}`);
            console.log(`Flow-production.json exists: ${fs_1.default.existsSync(accountsPath)}`);
            if (fs_1.default.existsSync(accountsPath)) {
                try {
                    const cfg = JSON.parse(fs_1.default.readFileSync(accountsPath, 'utf8'));
                    console.log('Flow-production.json loaded successfully');
                    console.log(`Accounts in flow-production.json: ${Object.keys(cfg.accounts || {}).join(', ')}`);
                    if (cfg.accounts && cfg.accounts['mainnet-agfarms']) {
                        address = String(cfg.accounts['mainnet-agfarms'].address);
                        console.log(`Found mainnet-agfarms address in flow-production.json: ${address}`);
                        if (cfg.accounts['mainnet-agfarms'].key && typeof cfg.accounts['mainnet-agfarms'].key.index === 'number') {
                            keyId = cfg.accounts['mainnet-agfarms'].key.index;
                        }
                        if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm) {
                            signatureAlgorithm = cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm;
                        }
                        if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.hashAlgorithm) {
                            hashAlgorithm = cfg.accounts['mainnet-agfarms'].key.hashAlgorithm;
                        }
                        console.log(`Key configuration: keyId=${keyId}, sigAlg=${signatureAlgorithm}, hashAlg=${hashAlgorithm}`);
                    }
                    else {
                        console.log('mainnet-agfarms account not found in flow-production.json');
                    }
                }
                catch (error) {
                    console.log(`Error loading flow-production.json: ${error}`);
                }
            }
        }
        const result = { address, key, keyId, signatureAlgorithm, hashAlgorithm };
        console.log('=== SERVICE ACCOUNT RESULT ===');
        console.log(`Address: ${result.address}`);
        console.log(`Key: ${result.key ? 'LOADED' : 'NOT LOADED'}`);
        console.log(`KeyId: ${result.keyId}`);
        console.log(`Signature Algorithm: ${result.signatureAlgorithm}`);
        console.log(`Hash Algorithm: ${result.hashAlgorithm}`);
        console.log('===============================');
        return result;
    }
    loadAccountByName(accountName, flowDir) {
        const keyPath = path_1.default.join(flowDir, 'accounts', 'pkeys', `${accountName}.pkey`);
        const key = fs_1.default.existsSync(keyPath) ? fs_1.default.readFileSync(keyPath, 'utf8').trim() : null;
        let address = null;
        let keyId = 0;
        let signatureAlgorithm = 'ECDSA_P256';
        let hashAlgorithm = 'SHA3_256';
        const flowJsonPath = path_1.default.join(flowDir, 'flow.json');
        if (fs_1.default.existsSync(flowJsonPath)) {
            try {
                const cfg = JSON.parse(fs_1.default.readFileSync(flowJsonPath, 'utf8'));
                if (cfg.accounts && cfg.accounts[accountName]) {
                    address = String(cfg.accounts[accountName].address);
                    if (cfg.accounts[accountName].key && typeof cfg.accounts[accountName].key.index === 'number') {
                        keyId = cfg.accounts[accountName].key.index;
                    }
                    if (cfg.accounts[accountName].key && cfg.accounts[accountName].key.signatureAlgorithm) {
                        signatureAlgorithm = cfg.accounts[accountName].key.signatureAlgorithm;
                    }
                    if (cfg.accounts[accountName].key && cfg.accounts[accountName].key.hashAlgorithm) {
                        hashAlgorithm = cfg.accounts[accountName].key.hashAlgorithm;
                    }
                }
            }
            catch { }
        }
        if (!address) {
            const accountsPath = path_1.default.join(flowDir, 'accounts', 'flow-production.json');
            if (fs_1.default.existsSync(accountsPath)) {
                try {
                    const cfg = JSON.parse(fs_1.default.readFileSync(accountsPath, 'utf8'));
                    if (cfg.accounts && cfg.accounts[accountName]) {
                        address = String(cfg.accounts[accountName].address);
                        if (cfg.accounts[accountName].key && typeof cfg.accounts[accountName].key.index === 'number') {
                            keyId = cfg.accounts[accountName].key.index;
                        }
                        if (cfg.accounts[accountName].key && cfg.accounts[accountName].key.signatureAlgorithm) {
                            signatureAlgorithm = cfg.accounts[accountName].key.signatureAlgorithm;
                        }
                        if (cfg.accounts[accountName].key && cfg.accounts[accountName].key.hashAlgorithm) {
                            hashAlgorithm = cfg.accounts[accountName].key.hashAlgorithm;
                        }
                    }
                }
                catch { }
            }
        }
        return { address, key, keyId, signatureAlgorithm, hashAlgorithm };
    }
    authzFactory(address, keyId, privateKey, signatureAlgorithm = 'ECDSA_P256', hashAlgorithm = 'SHA3_256') {
        const addrWithPrefix = address.startsWith('0x') ? address : `0x${address}`;
        // Determine the elliptic curve based on signature algorithm
        let curveName;
        if (signatureAlgorithm === 'ECDSA_secp256k1') {
            curveName = 'secp256k1';
        }
        else {
            curveName = 'p256'; // Default to P-256 for ECDSA_P256
        }
        const ec = new elliptic_1.ec(curveName);
        const key = ec.keyFromPrivate(Buffer.from(privateKey, 'hex'));
        return async function authz(account) {
            return {
                ...account,
                tempId: `${addrWithPrefix}-${keyId}`,
                addr: fcl.sansPrefix(addrWithPrefix),
                keyId: Number(keyId),
                signingFunction: async function (signable) {
                    const msgHex = signable.message;
                    const message = Buffer.from(msgHex, 'hex');
                    // Use the correct hash algorithm
                    let digest;
                    if (hashAlgorithm === 'SHA3_256') {
                        digest = crypto_1.default.createHash('sha3-256').update(message).digest();
                    }
                    else {
                        digest = crypto_1.default.createHash('sha256').update(message).digest();
                    }
                    const signature = key.sign(digest);
                    const n = 32;
                    const r = signature.r.toArrayLike(Buffer, 'be', n);
                    const s = signature.s.toArrayLike(Buffer, 'be', n);
                    const sigHex = Buffer.concat([r, s]).toString('hex');
                    return {
                        addr: fcl.withPrefix(addrWithPrefix),
                        keyId: Number(keyId),
                        signature: sigHex
                    };
                }
            };
        };
    }
    async executeScript(scriptPath, args = [], proposerWalletId) {
        console.log('=== FLOW SCRIPT EXECUTION ===');
        console.log(`Script Path: ${scriptPath}`);
        console.log(`Full Path: ${path_1.default.isAbsolute(scriptPath) ? scriptPath : path_1.default.join(this.config.flowDir, scriptPath)}`);
        console.log(`Arguments: ${JSON.stringify(args, null, 2)}`);
        console.log(`Network: ${this.config.network}`);
        console.log(`Flow Directory: ${this.config.flowDir}`);
        const startTime = Date.now();
        const fullPath = path_1.default.isAbsolute(scriptPath) ? scriptPath : path_1.default.join(this.config.flowDir, scriptPath);
        const code = await promises_1.default.readFile(fullPath, 'utf8');
        console.log(`Script Code Length: ${code.length} characters`);
        console.log(`Script Code Preview (first 200 chars): ${code.substring(0, 200)}...`);
        const fclArgs = args.map(arg => {
            if (typeof arg === 'string' && arg.startsWith('0x'))
                return fcl.arg(arg, fcl.t.Address);
            else if (typeof arg === 'string' && arg.includes('.'))
                return fcl.arg(arg, fcl.t.UFix64);
            else if (typeof arg === 'number') {
                // Ensure UFix64 values have at least one decimal place
                const numStr = arg.toString();
                const hasDecimal = numStr.includes('.');
                const formattedNum = hasDecimal ? numStr : `${numStr}.0`;
                return fcl.arg(formattedNum, fcl.t.UFix64);
            }
            else
                return fcl.arg(String(arg), fcl.t.String);
        });
        console.log(`FCL Arguments: ${JSON.stringify(fclArgs, null, 2)}`);
        // Create transaction record
        const transactionData = {
            transaction_type: 'script',
            status: 'pending',
            proposer_wallet_id: proposerWalletId,
            script_path: scriptPath,
            arguments: args,
            network: this.config.network,
            logs: [{
                    level: 'info',
                    message: 'Script execution started',
                    timestamp: new Date().toISOString()
                }]
        };
        const transaction = await supabase_1.transactionLogger.createTransaction(transactionData);
        try {
            const data = await fcl.query({ cadence: code, args: fclArgs });
            const executionTime = Date.now() - startTime;
            console.log(`Script Execution Result: ${JSON.stringify(data, null, 2)}`);
            console.log('=== SCRIPT EXECUTION COMPLETED ===');
            // Update transaction record with success
            if (transaction) {
                await supabase_1.transactionLogger.updateTransaction(transaction.id, {
                    status: 'executed',
                    result_data: data,
                    execution_time_ms: executionTime,
                    logs: [
                        ...(transaction.logs || []),
                        {
                            level: 'info',
                            message: 'Script execution completed successfully',
                            timestamp: new Date().toISOString(),
                            execution_time_ms: executionTime
                        }
                    ]
                });
            }
            return { success: true, data, transactionId: transaction?.id };
        }
        catch (error) {
            const executionTime = Date.now() - startTime;
            console.error(`Script Execution Error: ${error.message}`);
            console.error(`Error Stack: ${error.stack}`);
            console.log('=== SCRIPT EXECUTION FAILED ===');
            // Update transaction record with failure
            if (transaction) {
                await supabase_1.transactionLogger.updateTransaction(transaction.id, {
                    status: 'failed',
                    error_message: error.message,
                    execution_time_ms: executionTime,
                    logs: [
                        ...(transaction.logs || []),
                        {
                            level: 'error',
                            message: 'Script execution failed',
                            error: error.message,
                            stack: error.stack,
                            timestamp: new Date().toISOString(),
                            execution_time_ms: executionTime
                        }
                    ]
                });
            }
            return { success: false, errorMessage: error.message, data: null, transactionId: transaction?.id };
        }
    }
    async sendTransaction(transactionPath, args = [], roles = {}, privateKeys = {}, proposerWalletId, payerWalletId, authorizerWalletIds) {
        console.log('=== FLOW TRANSACTION EXECUTION ===');
        console.log(`Transaction Path: ${transactionPath}`);
        console.log(`Full Path: ${path_1.default.isAbsolute(transactionPath) ? transactionPath : path_1.default.join(this.config.flowDir, transactionPath)}`);
        console.log(`Arguments: ${JSON.stringify(args, null, 2)}`);
        console.log(`Roles: ${JSON.stringify(roles, null, 2)}`);
        console.log(`Network: ${this.config.network}`);
        console.log(`Flow Directory: ${this.config.flowDir}`);
        const startTime = Date.now();
        if (!this.authz) {
            console.error('Service account not configured');
            return { success: false, errorMessage: 'service account not configured' };
        }
        console.log(`Service Account Address: ${this.service.address}`);
        console.log(`Service Account Key ID: ${this.service.keyId}`);
        const fullPath = path_1.default.isAbsolute(transactionPath) ? transactionPath : path_1.default.join(this.config.flowDir, transactionPath);
        const code = await promises_1.default.readFile(fullPath, 'utf8');
        console.log(`Transaction Code Length: ${code.length} characters`);
        console.log(`Transaction Code Preview (first 300 chars): ${code.substring(0, 300)}...`);
        const fclArgs = args.map(arg => {
            if (typeof arg === 'string' && arg.startsWith('0x'))
                return fcl.arg(arg, fcl.t.Address);
            else if (typeof arg === 'string' && arg.includes('.'))
                return fcl.arg(arg, fcl.t.UFix64);
            else if (typeof arg === 'number') {
                // Ensure UFix64 values have at least one decimal place
                const numStr = arg.toString();
                const hasDecimal = numStr.includes('.');
                const formattedNum = hasDecimal ? numStr : `${numStr}.0`;
                return fcl.arg(formattedNum, fcl.t.UFix64);
            }
            else
                return fcl.arg(String(arg), fcl.t.String);
        });
        console.log(`FCL Arguments: ${JSON.stringify(fclArgs, null, 2)}`);
        // Create transaction record
        const transactionData = {
            transaction_type: 'transaction',
            status: 'pending',
            proposer_wallet_id: proposerWalletId,
            payer_wallet_id: payerWalletId,
            authorizer_wallet_ids: authorizerWalletIds,
            transaction_path: transactionPath,
            arguments: args,
            network: this.config.network,
            logs: [{
                    level: 'info',
                    message: 'Transaction execution started',
                    timestamp: new Date().toISOString()
                }]
        };
        const transaction = await supabase_1.transactionLogger.createTransaction(transactionData);
        // Normalize roles into FCL authorization functions
        const normalizeAuth = (val) => {
            if (!val)
                return this.authz;
            if (typeof val === 'function')
                return val;
            // If a string is provided, create authz for that account name
            if (typeof val === 'string') {
                console.log(`Loading account by name: ${val}`);
                // First check if we have a private key for this account
                if (privateKeys && privateKeys[val]) {
                    console.log(`Using private key for account: ${val}`);
                    // We need to get the address for this account
                    // For now, we'll assume the val is the address if it starts with 0x
                    if (val.startsWith('0x')) {
                        return this.authzFactory(val, 0, privateKeys[val], 'ECDSA_P256', 'SHA3_256');
                    }
                }
                const account = this.loadAccountByName(val, this.config.flowDir);
                console.log(`Account details for ${val}:`, {
                    address: account?.address,
                    keyId: account?.keyId,
                    hasKey: !!account?.key,
                    signatureAlgorithm: account?.signatureAlgorithm,
                    hashAlgorithm: account?.hashAlgorithm
                });
                if (account && account.address && account.key) {
                    return this.authzFactory(account.address, account.keyId || 0, account.key, account.signatureAlgorithm, account.hashAlgorithm);
                }
            }
            // Fall back to service authz if account not found
            return this.authz;
        };
        let authorizations = [];
        if (roles && roles.authorizer) {
            if (Array.isArray(roles.authorizer)) {
                console.log(`Multiple authorizers: ${roles.authorizer.join(', ')}`);
                authorizations = roles.authorizer.map(a => normalizeAuth(a));
            }
            else {
                console.log(`Single authorizer: ${roles.authorizer}`);
                authorizations = [normalizeAuth(roles.authorizer)];
            }
        }
        else {
            console.log('Using default service account as authorizer');
            authorizations = [this.authz];
        }
        const proposer = roles && roles.proposer ? normalizeAuth(roles.proposer) : this.authz;
        const payer = roles && roles.payer ? normalizeAuth(roles.payer) : this.authz;
        console.log(`Final Roles Configuration:`);
        console.log(`- Proposer: ${roles?.proposer || 'service account'}`);
        console.log(`- Payer: ${roles?.payer || 'service account'}`);
        console.log(`- Authorizers: ${roles?.authorizer ? (Array.isArray(roles.authorizer) ? roles.authorizer.join(', ') : roles.authorizer) : 'service account'}`);
        console.log(`- Number of authorizations: ${authorizations.length}`);
        const transactionConfig = {
            cadence: code,
            args: function (arg, t) { return fclArgs; },
            proposer: proposer,
            payer: payer,
            authorizations: authorizations,
            limit: 9999
        };
        console.log(`Transaction Configuration:`, {
            cadenceLength: transactionConfig.cadence.length,
            argsCount: fclArgs.length,
            authorizationsCount: authorizations.length,
            limit: transactionConfig.limit
        });
        try {
            console.log('Sending transaction to Flow network...');
            // Update transaction status to submitted
            if (transaction) {
                await supabase_1.transactionLogger.updateTransaction(transaction.id, {
                    status: 'submitted',
                    logs: [
                        ...(transaction.logs || []),
                        {
                            level: 'info',
                            message: 'Transaction submitted to Flow network',
                            timestamp: new Date().toISOString()
                        }
                    ]
                });
            }
            const txId = await fcl.mutate(transactionConfig);
            console.log(`Transaction ID: ${txId}`);
            // Update transaction with Flow transaction ID
            if (transaction) {
                await supabase_1.transactionLogger.updateTransaction(transaction.id, {
                    flow_transaction_id: txId,
                    status: 'submitted',
                    logs: [
                        ...(transaction.logs || []),
                        {
                            level: 'info',
                            message: 'Transaction submitted with Flow ID',
                            flow_transaction_id: txId,
                            timestamp: new Date().toISOString()
                        }
                    ]
                });
            }
            console.log('Waiting for transaction to be sealed...');
            const sealed = await fcl.tx(txId).onceSealed();
            const executionTime = Date.now() - startTime;
            console.log(`Transaction sealed successfully!`);
            console.log(`Sealed transaction data: ${JSON.stringify(sealed, null, 2)}`);
            console.log('=== TRANSACTION EXECUTION COMPLETED ===');
            // Update transaction with final results
            if (transaction) {
                // Extract blockchain data from sealed transaction and events
                let blockHeight = null;
                let blockTimestamp = null;
                let gasUsed = null;
                let gasLimit = null;
                // Try to get block height from blockId using Flow API
                try {
                    if (sealed.blockId) {
                        const block = await fcl.send([fcl.getBlock(), fcl.atBlockId(sealed.blockId)]);
                        const blockData = await fcl.decode(block);
                        blockHeight = blockData.height;
                        blockTimestamp = blockData.timestamp;
                        console.log(`Block details: height=${blockHeight}, timestamp=${blockTimestamp}`);
                    }
                }
                catch (blockError) {
                    console.log('Could not fetch block details:', blockError);
                }
                // Extract gas information from events
                const feesEvent = sealed.events?.find((event) => event.type === 'A.f919ee77447b7497.FlowFees.FeesDeducted');
                if (feesEvent) {
                    // Convert gas cost from FLOW to smallest unit and round to integer
                    gasUsed = Math.round(parseFloat(feesEvent.data.amount) * 100000000); // Convert to smallest unit and round
                    console.log(`Gas used: ${gasUsed} (from fees event)`);
                }
                // Log the extracted data
                console.log('=== EXTRACTED BLOCKCHAIN DATA ===');
                console.log('blockHeight:', blockHeight);
                console.log('blockTimestamp:', blockTimestamp);
                console.log('gasUsed:', gasUsed);
                console.log('gasLimit:', gasLimit);
                console.log('=================================');
                await supabase_1.transactionLogger.updateTransaction(transaction.id, {
                    status: 'sealed',
                    block_height: blockHeight,
                    block_timestamp: blockTimestamp ? new Date(blockTimestamp).toISOString() : null,
                    gas_used: gasUsed,
                    gas_limit: gasLimit,
                    result_data: sealed,
                    execution_time_ms: executionTime,
                    logs: [
                        ...(transaction.logs || []),
                        {
                            level: 'info',
                            message: 'Transaction sealed successfully',
                            block_height: blockHeight,
                            block_timestamp: blockTimestamp,
                            gas_used: gasUsed,
                            gas_limit: gasLimit,
                            execution_time_ms: executionTime,
                            timestamp: new Date().toISOString(),
                            block_id: sealed.blockId,
                            fees_event: feesEvent?.data
                        }
                    ]
                });
            }
            return { success: true, transactionId: txId, data: sealed, dbTransactionId: transaction?.id };
        }
        catch (error) {
            const executionTime = Date.now() - startTime;
            console.error(`Transaction Execution Error: ${error.message}`);
            console.error(`Error Stack: ${error.stack}`);
            console.log('=== TRANSACTION EXECUTION FAILED ===');
            // Update transaction with failure
            if (transaction) {
                await supabase_1.transactionLogger.updateTransaction(transaction.id, {
                    status: 'failed',
                    error_message: error.message,
                    execution_time_ms: executionTime,
                    logs: [
                        ...(transaction.logs || []),
                        {
                            level: 'error',
                            message: 'Transaction execution failed',
                            error: error.message,
                            stack: error.stack,
                            execution_time_ms: executionTime,
                            timestamp: new Date().toISOString()
                        }
                    ]
                });
            }
            return { success: false, errorMessage: error.message, transactionId: null, data: null, dbTransactionId: transaction?.id };
        }
    }
    async getAccount(address) {
        try {
            const account = await fcl.send([fcl.getAccount(address)]);
            const decoded = await fcl.decode(account);
            return new FlowResult({
                success: true,
                data: decoded
            });
        }
        catch (error) {
            return new FlowResult({
                success: false,
                errorMessage: error.message
            });
        }
    }
    async getTransaction(transactionId) {
        try {
            const tx = await fcl.tx(transactionId).onceSealed();
            return new FlowResult({
                success: true,
                data: tx
            });
        }
        catch (error) {
            return new FlowResult({
                success: false,
                errorMessage: error.message
            });
        }
    }
    async waitForTransactionSeal(transactionId, timeout = 300) {
        try {
            const sealed = await fcl.tx(transactionId).onceSealed();
            return new FlowResult({
                success: true,
                data: sealed,
                transactionId
            });
        }
        catch (error) {
            return new FlowResult({
                success: false,
                errorMessage: error.message,
                transactionId
            });
        }
    }
    updateConfig(options) {
        for (const [key, value] of Object.entries(options)) {
            if (this.config.hasOwnProperty(key)) {
                this.config[key] = value;
            }
        }
    }
    // Transaction management methods
    async getTransactionHistory(walletId, limit = 50) {
        return await supabase_1.transactionLogger.getTransactionsByWallet(walletId, limit);
    }
    async getTransactionById(transactionId) {
        return await supabase_1.transactionLogger.getTransaction(transactionId);
    }
    async getTransactionByFlowId(flowTransactionId) {
        return await supabase_1.transactionLogger.getTransactionByFlowId(flowTransactionId);
    }
    async addTransactionLog(transactionId, logEntry) {
        return await supabase_1.transactionLogger.addLog(transactionId, logEntry);
    }
    async updateTransactionStatus(transactionId, status, additionalData) {
        const updates = { status, ...additionalData };
        return await supabase_1.transactionLogger.updateTransaction(transactionId, updates);
    }
}
exports.FlowWrapper = FlowWrapper;
function createFlowWrapper(network = types_1.FlowNetwork.MAINNET, options = {}) {
    const config = new FlowConfig({ network: network, ...options });
    return new FlowWrapper(config);
}
async function executeScript(scriptPath, args = [], network = types_1.FlowNetwork.MAINNET, options = {}) {
    const wrapper = createFlowWrapper(network, options);
    return await wrapper.executeScript(scriptPath, args);
}
async function sendTransaction(transactionPath, args = [], roles = {}, network = types_1.FlowNetwork.MAINNET, options = {}) {
    const wrapper = createFlowWrapper(network, options);
    return await wrapper.sendTransaction(transactionPath, args, roles);
}
