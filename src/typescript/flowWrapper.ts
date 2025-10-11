import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import { ec as EC } from 'elliptic';
import nodeCrypto from 'crypto';
import * as fcl from '@onflow/fcl';
import { FlowNetwork, FlowResultOptions } from './types';
import { transactionLogger, Transaction } from './supabase';

export class FlowResult {
    success: boolean;
    data: any;
    errorMessage: string;
    transactionId: string | null;
    executionTime: number;
    blockHeight: number | null;
    blockTimestamp: string | null;
    gasUsed: number | null;

    constructor(options: FlowResultOptions = {}) {
        this.success = options.success || false;
        this.data = options.data || null;
        this.errorMessage = options.errorMessage || "";
        this.transactionId = options.transactionId || null;
        this.executionTime = options.executionTime || 0;
        this.blockHeight = options.blockHeight || null;
        this.blockTimestamp = options.blockTimestamp || null;
        this.gasUsed = options.gasUsed || null;
    }

    toDict() {
        return {
            success: this.success,
            data: this.data,
            errorMessage: this.errorMessage,
            transactionId: this.transactionId,
            executionTime: this.executionTime,
            blockHeight: this.blockHeight,
            blockTimestamp: this.blockTimestamp,
            gasUsed: this.gasUsed
        };
    }
}

export class FlowConfig {
    network: FlowNetwork;
    flowDir: string;

    constructor(options: Partial<FlowConfig> = {}) {
        this.network = (options.network as FlowNetwork) || FlowNetwork.MAINNET;
        this.flowDir = options.flowDir || path.join(process.cwd(), 'flow');
    }
}


export class FlowWrapper {
    config: FlowConfig;
    service: { address: string | null; key: string | null; keyId: number };
    authz: any;
    private transactionLock: boolean = false;
    private transactionQueue: Array<() => Promise<any>> = [];

    constructor(config: Partial<FlowConfig> = {}) {
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

        console.error('=== FLOW WRAPPER CONSTRUCTOR DEBUG ===');
        console.error('Loading service account from:', this.config.flowDir);
        
        const svc = this.loadServiceAccount(this.config.flowDir);
        this.service = svc;
        
        console.error('Service account loaded:', {
            address: svc.address,
            hasKey: !!svc.key,
            keyId: svc.keyId,
            signatureAlgorithm: svc.signatureAlgorithm,
            hashAlgorithm: svc.hashAlgorithm
        });
        
        // Clean service account setup log
        console.log(`🔑 Service: ${svc.address} (key: ${svc.key ? '✓' : '✗'})`);
        
        this.authz = svc.address && svc.key ? this.authzFactory(svc.address, svc.keyId || 0, svc.key, svc.signatureAlgorithm, svc.hashAlgorithm) : null;
        
        console.error('Authorization created:', !!this.authz);
        console.error('=== END FLOW WRAPPER CONSTRUCTOR DEBUG ===');
    }

    getAccessNode(network: FlowNetwork) {
        if (network === FlowNetwork.MAINNET) return 'https://rest-mainnet.onflow.org';
        if (network === FlowNetwork.TESTNET) return 'https://rest-testnet.onflow.org';
        return 'http://127.0.0.1:8888';
    }

    loadFlowConfig() {
        const flowJsonPath = path.join(this.config.flowDir, 'flow.json');
        if (!fsSync.existsSync(flowJsonPath)) {
            throw new Error(`Flow config file not found: ${flowJsonPath}`);
        }
        
        const flowConfig = JSON.parse(fsSync.readFileSync(flowJsonPath, 'utf8'));
        if (flowConfig.contracts) {
            for (const [contractName, contractConfig] of Object.entries<any>(flowConfig.contracts)) {
                if (contractConfig.aliases && contractConfig.aliases[this.config.network]) {
                    const address = String(contractConfig.aliases[this.config.network]);
                    const withPrefix = address.startsWith('0x') ? address : `0x${address}`;
                    fcl.config()
                        .put(`0x${contractName}`, withPrefix)
                        .put(`contracts.${contractName}`, withPrefix);
                }
            }
        }
    }

    loadServiceAccount(flowDir: string) {
        const keyPath = path.join(flowDir, 'mainnet-agfarms.pkey');
        if (!fsSync.existsSync(keyPath)) {
            throw new Error(`Service account private key not found: ${keyPath}`);
        }
        const key = fsSync.readFileSync(keyPath, 'utf8').trim();
        
        let address: string | null = null;
        let keyId = 0;
        let signatureAlgorithm = 'ECDSA_secp256k1';
        let hashAlgorithm = 'SHA2_256';

        const flowJsonPath = path.join(flowDir, 'flow.json');
        
        if (fsSync.existsSync(flowJsonPath)) {
            const cfg = JSON.parse(fsSync.readFileSync(flowJsonPath, 'utf8'));
            
            if (cfg.accounts && cfg.accounts['mainnet-agfarms']) {
                address = String(cfg.accounts['mainnet-agfarms'].address);
                
                if (cfg.accounts['mainnet-agfarms'].key && typeof cfg.accounts['mainnet-agfarms'].key.index === 'number') {
                    keyId = cfg.accounts['mainnet-agfarms'].key.index;
                }
                if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm) {
                    signatureAlgorithm = cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm;
                }
                if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.hashAlgorithm) {
                    hashAlgorithm = cfg.accounts['mainnet-agfarms'].key.hashAlgorithm;
                }
            }
        }

        if (!address) {
            const accountsPath = path.join(flowDir, 'accounts', 'flow-production.json');
            
            if (fsSync.existsSync(accountsPath)) {
                const cfg = JSON.parse(fsSync.readFileSync(accountsPath, 'utf8'));
                
                if (cfg.accounts && cfg.accounts['mainnet-agfarms']) {
                    address = String(cfg.accounts['mainnet-agfarms'].address);
                    
                    if (cfg.accounts['mainnet-agfarms'].key && typeof cfg.accounts['mainnet-agfarms'].key.index === 'number') {
                        keyId = cfg.accounts['mainnet-agfarms'].key.index;
                    }
                    if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm) {
                        signatureAlgorithm = cfg.accounts['mainnet-agfarms'].key.signatureAlgorithm;
                    }
                    if (cfg.accounts['mainnet-agfarms'].key && cfg.accounts['mainnet-agfarms'].key.hashAlgorithm) {
                        hashAlgorithm = cfg.accounts['mainnet-agfarms'].key.hashAlgorithm;
                    }
                }
            }
        }
        
        if (!address) {
            throw new Error('Service account address not found in flow.json or flow-production.json');
        }
        
        return { address, key, keyId, signatureAlgorithm, hashAlgorithm };
    }

    loadAccountByName(accountName: string, flowDir: string) {
        const keyPath = path.join(flowDir, 'accounts', 'pkeys', `${accountName}.pkey`);
        if (!fsSync.existsSync(keyPath)) {
            throw new Error(`Private key file not found for account ${accountName}: ${keyPath}`);
        }
        const key = fsSync.readFileSync(keyPath, 'utf8').trim();
        let address: string | null = null;
        let keyId = 0;
        let signatureAlgorithm = 'ECDSA_P256';
        let hashAlgorithm = 'SHA3_256';

        const flowJsonPath = path.join(flowDir, 'flow.json');
        if (fsSync.existsSync(flowJsonPath)) {
            const cfg = JSON.parse(fsSync.readFileSync(flowJsonPath, 'utf8'));
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

        if (!address) {
            const accountsPath = path.join(flowDir, 'accounts', 'flow-production.json');
            if (fsSync.existsSync(accountsPath)) {
                const cfg = JSON.parse(fsSync.readFileSync(accountsPath, 'utf8'));
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
        }
        
        if (!address) {
            throw new Error(`Account ${accountName} not found in flow.json or flow-production.json`);
        }
        
        return { address, key, keyId, signatureAlgorithm, hashAlgorithm };
    }

    authzFactory(address: string, keyId: number, privateKey: string, signatureAlgorithm: string = 'ECDSA_P256', hashAlgorithm: string = 'SHA3_256') {
        const addrWithPrefix = address.startsWith('0x') ? address : `0x${address}`;
        
        // Determine the elliptic curve based on signature algorithm
        let curveName: string;
        if (signatureAlgorithm === 'ECDSA_secp256k1') {
            curveName = 'secp256k1';
        } else {
            curveName = 'p256'; // Default to P-256 for ECDSA_P256
        }
        
        const ec = new EC(curveName);
        const key = ec.keyFromPrivate(Buffer.from(privateKey, 'hex'));
        
        return async function authz(account: any) {
            return {
                ...account,
                tempId: `${addrWithPrefix}-${keyId}`,
                addr: fcl.sansPrefix(addrWithPrefix),
                keyId: Number(keyId),
                signingFunction: async function(signable: any) {
                    const msgHex = signable.message;
                    const message = Buffer.from(msgHex, 'hex');
                    
                    // Use the correct hash algorithm
                    let digest: Buffer;
                    if (hashAlgorithm === 'SHA3_256') {
                        digest = nodeCrypto.createHash('sha3-256').update(message).digest();
                    } else {
                        digest = nodeCrypto.createHash('sha256').update(message).digest();
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

    async executeScript(scriptPath: string, args: any[] = [], proposerWalletId?: string) {
        const startTime = Date.now();
        const fullPath = path.isAbsolute(scriptPath) ? scriptPath : path.join(this.config.flowDir, scriptPath);
        const code = await fs.readFile(fullPath, 'utf8');
        
        console.log(`📜 Script: ${path.basename(scriptPath)} (${args.length} args)`);
        
        const fclArgs = this._buildFclArgs(args);
        const transaction = await this._createTransactionRecord('script', scriptPath, args, proposerWalletId);
        
        try {
            const data = await fcl.query({
                cadence: code,
                args: (arg: any, t: any) => fclArgs
            });
            
            const executionTime = Date.now() - startTime;
            console.log(`✅ Script completed (${executionTime}ms)`);
            
            await this._updateTransactionSuccess(transaction, data, executionTime);
            
            return new FlowResult({
                success: true,
                data,
                transactionId: transaction?.id,
                executionTime
            });
        } catch (error: any) {
            const executionTime = Date.now() - startTime;
            console.log(`❌ Script failed (${executionTime}ms): ${error.message}`);
            
            await this._updateTransactionFailure(transaction, error, executionTime);
            
            return new FlowResult({
                success: false,
                errorMessage: error.message,
                transactionId: transaction?.id,
                executionTime
            });
        }
    }

    async sendTransaction(transactionPath: string, args: any[] = [], roles: { proposer?: any; payer?: any; authorizer?: any | any[] } = {}, privateKeys: any = {}, proposerWalletId?: string, payerWalletId?: string, authorizerWalletIds?: string[]) {
        return new Promise((resolve, reject) => {
            const transactionFunction = async () => {
                try {
                    const result = await this._executeTransaction(transactionPath, args, roles, privateKeys, proposerWalletId, payerWalletId, authorizerWalletIds);
                    resolve(result);
                } catch (error) {
                    reject(error);
                }
            };

            this.transactionQueue.push(transactionFunction);
            this._processTransactionQueue();
        });
    }

    private async _processTransactionQueue() {
        if (this.transactionLock || this.transactionQueue.length === 0) {
            return;
        }

        this.transactionLock = true;
        console.log(`🔒 Transaction lock acquired. Queue size: ${this.transactionQueue.length}`);

        while (this.transactionQueue.length > 0) {
            const transactionFunction = this.transactionQueue.shift();
            if (transactionFunction) {
                try {
                    await transactionFunction();
                } catch (error) {
                    console.error('Transaction in queue failed:', error);
                }
            }
        }

        this.transactionLock = false;
        console.log('🔓 Transaction lock released');
    }

    private async _executeTransaction(transactionPath: string, args: any[] = [], roles: { proposer?: any; payer?: any; authorizer?: any | any[] } = {}, privateKeys: any = {}, proposerWalletId?: string, payerWalletId?: string, authorizerWalletIds?: string[]) {
        const startTime = Date.now();
        
        if (!this.authz) {
            console.log('❌ Service account not configured');
            return new FlowResult({
                success: false,
                errorMessage: 'Service account not configured',
                executionTime: 0
            });
        }
        
        const fullPath = path.isAbsolute(transactionPath) ? transactionPath : path.join(this.config.flowDir, transactionPath);
        const code = await fs.readFile(fullPath, 'utf8');
        
        console.log(`💸 Transaction: ${path.basename(transactionPath)} (${args.length} args)`);
        
        const fclArgs = this._buildFclArgs(args);
        const transaction = await this._createTransactionRecord('transaction', transactionPath, args, proposerWalletId, payerWalletId, authorizerWalletIds);
        
        // Use the provided roles for Flow transaction execution
        // Wallet IDs are only used for database logging, not for Flow account resolution
        const transactionRoles = {
            proposer: roles.proposer,
            payer: roles.payer,
            authorizer: roles.authorizer
        };
        
        const { proposer, payer, authorizations } = this._setupTransactionRoles(transactionRoles, privateKeys);
        
        const transactionConfig = {
            cadence: code,
            args: function(arg: any, t: any) { return fclArgs; },
            proposer: proposer,
            payer: payer,
            authorizations: authorizations,
            limit: 9999
        };
        
        try {
            await this._updateTransactionStatus(transaction, 'submitted', 'Transaction submitted to Flow network');
            
            const txId = await (fcl as any).mutate(transactionConfig);
            
            await this._updateTransactionStatus(transaction, 'submitted', 'Transaction submitted with Flow ID', { flow_transaction_id: txId });
            
            const sealed = await (fcl as any).tx(txId).onceSealed();
            const executionTime = Date.now() - startTime;
            
            console.log(`✅ Transaction sealed (${executionTime}ms): ${txId}`);
            
            const { blockHeight, blockTimestamp, gasUsed } = await this._extractBlockchainData(sealed);
            
            await this._updateTransactionSealed(transaction, sealed, executionTime, blockHeight, blockTimestamp, gasUsed);
            
            return new FlowResult({
                success: true,
                data: sealed,
                transactionId: txId,
                executionTime,
                blockHeight,
                blockTimestamp,
                gasUsed
            });
        } catch (error: any) {
            const executionTime = Date.now() - startTime;
            console.log(`❌ Transaction failed (${executionTime}ms): ${error.message}`);
            
            await this._updateTransactionFailure(transaction, error, executionTime);
            
            return new FlowResult({
                success: false,
                errorMessage: error.message,
                transactionId: null,
                executionTime
            });
        }
    }

    private _buildFclArgs(args: any[]) {
        return args.map(arg => {
            if (typeof arg === 'string') {
                if (arg.startsWith('0x') || /^[0-9a-fA-F]{16}$/.test(arg) || /^[0-9a-fA-F-]{36}$/.test(arg)) {
                    return fcl.arg(arg, (fcl as any).t.Address);
                } else if (arg.includes('.')) {
                    return fcl.arg(arg, (fcl as any).t.UFix64);
                } else {
                    return fcl.arg(arg, (fcl as any).t.String);
                }
            } else if (typeof arg === 'number') {
                const numStr = arg.toString();
                const hasDecimal = numStr.includes('.');
                const formattedNum = hasDecimal ? numStr : `${numStr}.0`;
                return fcl.arg(formattedNum, (fcl as any).t.UFix64);
            } else {
                return fcl.arg(String(arg), (fcl as any).t.String);
            }
        });
    }

    private _isValidWalletId(id: string | undefined): boolean {
        if (!id) return false;
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        return uuidRegex.test(id);
    }

    private async _createTransactionRecord(type: 'script' | 'transaction', path: string, args: any[], proposerWalletId?: string, payerWalletId?: string, authorizerWalletIds?: string[]) {
        const transactionData: Partial<Transaction> = {
            transaction_type: type,
            status: 'pending',
            proposer_wallet_id: this._isValidWalletId(proposerWalletId) ? proposerWalletId : undefined,
            payer_wallet_id: this._isValidWalletId(payerWalletId) ? payerWalletId : undefined,
            authorizer_wallet_ids: authorizerWalletIds?.filter(this._isValidWalletId),
            script_path: type === 'script' ? path : undefined,
            transaction_path: type === 'transaction' ? path : undefined,
            arguments: args,
            network: this.config.network,
            logs: [{
                level: 'info',
                message: `${type === 'script' ? 'Script' : 'Transaction'} execution started`,
                timestamp: new Date().toISOString()
            }]
        };
        
        try {
            return await transactionLogger.createTransaction(transactionData);
        } catch (error: any) {
            // If there's a foreign key constraint error, skip transaction logging
            if (error?.code === '23503' || error?.message?.includes('foreign key constraint')) {
                console.warn(`Skipping transaction logging due to foreign key constraint: ${error.message}`);
                return null;
            }
            throw error;
        }
    }

    private async _updateTransactionSuccess(transaction: any, data: any, executionTime: number) {
        if (transaction) {
            await transactionLogger.updateTransaction(transaction.id!, {
                status: 'executed',
                result_data: data,
                execution_time_ms: executionTime,
                logs: [
                    ...(transaction.logs || []),
                    {
                        level: 'info',
                        message: 'Execution completed successfully',
                        timestamp: new Date().toISOString(),
                        execution_time_ms: executionTime
                    }
                ]
            });
        }
    }

    private async _updateTransactionFailure(transaction: any, error: any, executionTime: number) {
        if (transaction) {
            await transactionLogger.updateTransaction(transaction.id!, {
                status: 'failed',
                error_message: error.message,
                execution_time_ms: executionTime,
                logs: [
                    ...(transaction.logs || []),
                    {
                        level: 'error',
                        message: 'Execution failed',
                        error: error.message,
                        stack: error.stack,
                        timestamp: new Date().toISOString(),
                        execution_time_ms: executionTime
                    }
                ]
            });
        }
    }

    private async _updateTransactionStatus(transaction: any, status: string, message: string, additionalData?: any) {
        if (transaction) {
            await transactionLogger.updateTransaction(transaction.id!, {
                status: status as any,
                ...additionalData,
                logs: [
                    ...(transaction.logs || []),
                    {
                        level: 'info',
                        message,
                        timestamp: new Date().toISOString()
                    }
                ]
            });
        }
    }

    private async _updateTransactionSealed(transaction: any, sealed: any, executionTime: number, blockHeight: number | null, blockTimestamp: string | null, gasUsed: number | null) {
        if (transaction) {
            await transactionLogger.updateTransaction(transaction.id!, {
                status: 'sealed',
                block_height: blockHeight,
                block_timestamp: blockTimestamp,
                gas_used: gasUsed,
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
                        execution_time_ms: executionTime,
                        timestamp: new Date().toISOString(),
                        block_id: sealed.blockId
                    }
                ]
            });
        }
    }

    private async _extractBlockchainData(sealed: any) {
        let blockHeight = null;
        let blockTimestamp = null;
        let gasUsed = null;
        
        try {
            if (sealed.blockId) {
                const block = await fcl.send([fcl.getBlock(), fcl.atBlockId(sealed.blockId)]);
                const blockData = await fcl.decode(block);
                blockHeight = blockData.height;
                blockTimestamp = blockData.timestamp ? new Date(blockData.timestamp).toISOString() : null;
            }
        } catch (blockError) {
            // Silent fail for block details
        }
        
        const feesEvent = sealed.events?.find((event: any) => 
            event.type === 'A.f919ee77447b7497.FlowFees.FeesDeducted'
        );
        
        if (feesEvent) {
            gasUsed = Math.round(parseFloat(feesEvent.data.amount) * 100000000);
        }
        
        return { blockHeight, blockTimestamp, gasUsed };
    }

    private _setupTransactionRoles(roles: any, privateKeys: any) {
        const normalizeAuth = (val: any) => {
            if (!val) {
                throw new Error('No authorization value provided');
            }
            if (typeof val === 'function') return val;
            if (typeof val === 'string') {
                if (privateKeys && privateKeys[val]) {
                    if (val.startsWith('0x')) {
                        return this.authzFactory(val, 0, privateKeys[val], 'ECDSA_P256', 'SHA3_256');
                    }
                }
                
                const account = this.loadAccountByName(val, this.config.flowDir);
                return this.authzFactory(account.address, account.keyId || 0, account.key, account.signatureAlgorithm, account.hashAlgorithm);
            }
            throw new Error(`Invalid authorization value: ${val}`);
        };
        
        let authorizations: any[] = [];
        if (roles && roles.authorizer) {
            if (Array.isArray(roles.authorizer)) {
                authorizations = roles.authorizer.map(a => normalizeAuth(a));
            } else {
                authorizations = [normalizeAuth(roles.authorizer)];
            }
        } else {
            authorizations = [this.authz];
        }
        
        const proposer = roles && roles.proposer ? normalizeAuth(roles.proposer) : this.authz;
        const payer = roles && roles.payer ? normalizeAuth(roles.payer) : this.authz;
        
        return { proposer, payer, authorizations };
    }

    async getAccount(address: string) {
        try {
            const account = await fcl.send([fcl.getAccount(address)]);
            const decoded = await fcl.decode(account);
            return new FlowResult({
                success: true,
                data: decoded
            });
        } catch (error: any) {
            return new FlowResult({
                success: false,
                errorMessage: error.message
            });
        }
    }

    async getTransaction(transactionId: string) {
        const startTime = Date.now();
        try {
            const tx = await fcl.tx(transactionId).onceSealed();
            const executionTime = Date.now() - startTime;
            return new FlowResult({
                success: true,
                data: tx,
                transactionId,
                executionTime
            });
        } catch (error: any) {
            const executionTime = Date.now() - startTime;
            return new FlowResult({
                success: false,
                errorMessage: error.message,
                transactionId,
                executionTime
            });
        }
    }

    async waitForTransactionSeal(transactionId: string, timeout = 300) {
        const startTime = Date.now();
        try {
            const sealed = await fcl.tx(transactionId).onceSealed();
            const executionTime = Date.now() - startTime;
            return new FlowResult({
                success: true,
                data: sealed,
                transactionId,
                executionTime
            });
        } catch (error: any) {
            const executionTime = Date.now() - startTime;
            return new FlowResult({
                success: false,
                errorMessage: error.message,
                transactionId,
                executionTime
            });
        }
    }

    updateConfig(options: Partial<FlowConfig>) {
        for (const [key, value] of Object.entries(options)) {
            if ((this.config as any).hasOwnProperty(key)) {
                (this.config as any)[key] = value as any;
            }
        }
    }

    // Transaction management methods
    async getTransactionHistory(walletId: string, limit: number = 50) {
        return await transactionLogger.getTransactionsByWallet(walletId, limit);
    }

    async getTransactionById(transactionId: string) {
        return await transactionLogger.getTransaction(transactionId);
    }

    async getTransactionByFlowId(flowTransactionId: string) {
        return await transactionLogger.getTransactionByFlowId(flowTransactionId);
    }

    async addTransactionLog(transactionId: string, logEntry: any) {
        return await transactionLogger.addLog(transactionId, logEntry);
    }

    async updateTransactionStatus(transactionId: string, status: Transaction['status'], additionalData?: Partial<Transaction>) {
        const updates: Partial<Transaction> = { status, ...additionalData };
        return await transactionLogger.updateTransaction(transactionId, updates);
    }
}

export function createFlowWrapper(network: FlowNetwork | string = FlowNetwork.MAINNET, options: Partial<FlowConfig> = {}) {
    const config = new FlowConfig({ network: network as any, ...options });
    return new FlowWrapper(config);
}

export async function executeScript(scriptPath: string, args: any[] = [], network: FlowNetwork | string = FlowNetwork.MAINNET, options: Partial<FlowConfig> = {}) {
    const wrapper = createFlowWrapper(network as any, options);
    return await wrapper.executeScript(scriptPath, args);
}

export async function sendTransaction(transactionPath: string, args: any[] = [], roles: { proposer?: any; payer?: any; authorizer?: any | any[] } = {}, network: FlowNetwork | string = FlowNetwork.MAINNET, options: Partial<FlowConfig> = {}) {
    const wrapper = createFlowWrapper(network as any, options);
    return await wrapper.sendTransaction(transactionPath, args, roles);
}

