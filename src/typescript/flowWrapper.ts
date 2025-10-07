import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import { ec as EC } from 'elliptic';
import nodeCrypto from 'crypto';
import * as fcl from '@onflow/fcl';
import { FlowNetwork, FlowResultOptions } from './types';

export class FlowResult {
    success: boolean;
    data: any;
    errorMessage: string;
    transactionId: string | null;

    constructor(options: FlowResultOptions = {}) {
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

        const svc = this.loadServiceAccount(this.config.flowDir);
        this.service = svc;
        this.authz = svc.address && svc.key ? this.authzFactory(svc.address, svc.keyId || 0, svc.key, svc.signatureAlgorithm, svc.hashAlgorithm) : null;
    }

    getAccessNode(network: FlowNetwork) {
        if (network === FlowNetwork.MAINNET) return 'https://rest-mainnet.onflow.org';
        if (network === FlowNetwork.TESTNET) return 'https://rest-testnet.onflow.org';
        return 'http://127.0.0.1:8888';
    }

    loadFlowConfig() {
        const flowJsonPath = path.join(this.config.flowDir, 'flow.json');
        if (fsSync.existsSync(flowJsonPath)) {
            try {
                const flowConfig = JSON.parse(fsSync.readFileSync(flowJsonPath, 'utf8'));
                if (flowConfig.contracts) {
                    for (const [contractName, contractConfig] of Object.entries<any>(flowConfig.contracts)) {
                        if (contractConfig.aliases && contractConfig.aliases[this.config.network]) {
                            const address = String(contractConfig.aliases[this.config.network]);
                            const withPrefix = address.startsWith('0x') ? address : `0x${address}`;
                            fcl.config().put(`0x${contractName}`, withPrefix);
                        }
                    }
                }
            } catch {}
        }
    }

    loadServiceAccount(flowDir: string) {
        const keyPath = path.join(flowDir, 'mainnet-agfarms.pkey');
        const key = fsSync.existsSync(keyPath) ? fsSync.readFileSync(keyPath, 'utf8').trim() : null;
        let address: string | null = null;
        let keyId = 0;
        let signatureAlgorithm = 'ECDSA_secp256k1';
        let hashAlgorithm = 'SHA2_256';

        const flowJsonPath = path.join(flowDir, 'flow.json');
        if (fsSync.existsSync(flowJsonPath)) {
            try {
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
            } catch {}
        }

        if (!address) {
            const accountsPath = path.join(flowDir, 'accounts', 'flow-production.json');
            if (fsSync.existsSync(accountsPath)) {
                try {
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
                } catch {}
            }
        }
        return { address, key, keyId, signatureAlgorithm, hashAlgorithm };
    }

    loadAccountByName(accountName: string, flowDir: string) {
        const keyPath = path.join(flowDir, 'accounts', 'pkeys', `${accountName}.pkey`);
        const key = fsSync.existsSync(keyPath) ? fsSync.readFileSync(keyPath, 'utf8').trim() : null;
        let address: string | null = null;
        let keyId = 0;
        let signatureAlgorithm = 'ECDSA_P256';
        let hashAlgorithm = 'SHA3_256';

        const flowJsonPath = path.join(flowDir, 'flow.json');
        if (fsSync.existsSync(flowJsonPath)) {
            try {
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
            } catch {}
        }

        if (!address) {
            const accountsPath = path.join(flowDir, 'accounts', 'flow-production.json');
            if (fsSync.existsSync(accountsPath)) {
                try {
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
                } catch {}
            }
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

    async executeScript(scriptPath: string, args: any[] = []) {
        console.log('=== FLOW SCRIPT EXECUTION ===');
        console.log(`Script Path: ${scriptPath}`);
        console.log(`Full Path: ${path.isAbsolute(scriptPath) ? scriptPath : path.join(this.config.flowDir, scriptPath)}`);
        console.log(`Arguments: ${JSON.stringify(args, null, 2)}`);
        console.log(`Network: ${this.config.network}`);
        console.log(`Flow Directory: ${this.config.flowDir}`);
        
        const fullPath = path.isAbsolute(scriptPath) ? scriptPath : path.join(this.config.flowDir, scriptPath);
        const code = await fs.readFile(fullPath, 'utf8');
        
        console.log(`Script Code Length: ${code.length} characters`);
        console.log(`Script Code Preview (first 200 chars): ${code.substring(0, 200)}...`);
        
        const fclArgs = args.map(arg => {
            if (typeof arg === 'string' && arg.startsWith('0x')) return fcl.arg(arg, (fcl as any).t.Address);
            else if (typeof arg === 'string' && arg.includes('.')) return fcl.arg(arg, (fcl as any).t.UFix64);
            else if (typeof arg === 'number') return fcl.arg(arg.toString(), (fcl as any).t.UFix64);
            else return fcl.arg(String(arg), (fcl as any).t.String);
        });
        
        console.log(`FCL Arguments: ${JSON.stringify(fclArgs, null, 2)}`);
        
        try {
            const data = await (fcl as any).query({ cadence: code, args: fclArgs });
            console.log(`Script Execution Result: ${JSON.stringify(data, null, 2)}`);
            console.log('=== SCRIPT EXECUTION COMPLETED ===');
            return { success: true, data };
        } catch (error: any) {
            console.error(`Script Execution Error: ${error.message}`);
            console.error(`Error Stack: ${error.stack}`);
            console.log('=== SCRIPT EXECUTION FAILED ===');
            return { success: false, errorMessage: error.message, data: null };
        }
    }

    async sendTransaction(transactionPath: string, args: any[] = [], roles: { proposer?: any; payer?: any; authorizer?: any | any[] } = {}, privateKeys: any = {}) {
        console.log('=== FLOW TRANSACTION EXECUTION ===');
        console.log(`Transaction Path: ${transactionPath}`);
        console.log(`Full Path: ${path.isAbsolute(transactionPath) ? transactionPath : path.join(this.config.flowDir, transactionPath)}`);
        console.log(`Arguments: ${JSON.stringify(args, null, 2)}`);
        console.log(`Roles: ${JSON.stringify(roles, null, 2)}`);
        console.log(`Network: ${this.config.network}`);
        console.log(`Flow Directory: ${this.config.flowDir}`);
        
        if (!this.authz) {
            console.error('Service account not configured');
            return { success: false, errorMessage: 'service account not configured' };
        }
        
        console.log(`Service Account Address: ${this.service.address}`);
        console.log(`Service Account Key ID: ${this.service.keyId}`);
        
        const fullPath = path.isAbsolute(transactionPath) ? transactionPath : path.join(this.config.flowDir, transactionPath);
        const code = await fs.readFile(fullPath, 'utf8');
        
        console.log(`Transaction Code Length: ${code.length} characters`);
        console.log(`Transaction Code Preview (first 300 chars): ${code.substring(0, 300)}...`);
        
        const fclArgs = args.map(arg => {
            if (typeof arg === 'string' && arg.startsWith('0x')) return fcl.arg(arg, (fcl as any).t.Address);
            else if (typeof arg === 'string' && arg.includes('.')) return fcl.arg(arg, (fcl as any).t.UFix64);
            else if (typeof arg === 'number') return fcl.arg(arg.toString(), (fcl as any).t.UFix64);
            else return fcl.arg(String(arg), (fcl as any).t.String);
        });
        
        console.log(`FCL Arguments: ${JSON.stringify(fclArgs, null, 2)}`);
        
        // Normalize roles into FCL authorization functions
        const normalizeAuth = (val: any) => {
            if (!val) return this.authz;
            if (typeof val === 'function') return val;
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
        
        let authorizations: any[] = [];
        if (roles && roles.authorizer) {
            if (Array.isArray(roles.authorizer)) {
                console.log(`Multiple authorizers: ${roles.authorizer.join(', ')}`);
                authorizations = roles.authorizer.map(a => normalizeAuth(a));
            } else {
                console.log(`Single authorizer: ${roles.authorizer}`);
                authorizations = [normalizeAuth(roles.authorizer)];
            }
        } else {
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
            args: function(arg: any, t: any) { return fclArgs; },
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
            const txId = await (fcl as any).mutate(transactionConfig);
            console.log(`Transaction ID: ${txId}`);
            console.log('Waiting for transaction to be sealed...');
            
            const sealed = await (fcl as any).tx(txId).onceSealed();
            console.log(`Transaction sealed successfully!`);
            console.log(`Sealed transaction data: ${JSON.stringify(sealed, null, 2)}`);
            console.log('=== TRANSACTION EXECUTION COMPLETED ===');
            
            return { success: true, transactionId: txId, data: sealed };
        } catch (error: any) {
            console.error(`Transaction Execution Error: ${error.message}`);
            console.error(`Error Stack: ${error.stack}`);
            console.log('=== TRANSACTION EXECUTION FAILED ===');
            return { success: false, errorMessage: error.message, transactionId: null, data: null };
        }
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
        try {
            const tx = await fcl.tx(transactionId).onceSealed();
            return new FlowResult({
                success: true,
                data: tx
            });
        } catch (error: any) {
            return new FlowResult({
                success: false,
                errorMessage: error.message
            });
        }
    }

    async waitForTransactionSeal(transactionId: string, timeout = 300) {
        try {
            const sealed = await fcl.tx(transactionId).onceSealed();
            return new FlowResult({
                success: true,
                data: sealed,
                transactionId
            });
        } catch (error: any) {
            return new FlowResult({
                success: false,
                errorMessage: error.message,
                transactionId
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
