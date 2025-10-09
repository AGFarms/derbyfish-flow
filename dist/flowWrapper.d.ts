import { FlowNetwork, FlowResultOptions } from './types';
import { Transaction } from './supabase';
export declare class FlowResult {
    success: boolean;
    data: any;
    errorMessage: string;
    transactionId: string | null;
    executionTime: number;
    blockHeight: number | null;
    blockTimestamp: string | null;
    gasUsed: number | null;
    constructor(options?: FlowResultOptions);
    toDict(): {
        success: boolean;
        data: any;
        errorMessage: string;
        transactionId: string;
        executionTime: number;
        blockHeight: number;
        blockTimestamp: string;
        gasUsed: number;
    };
}
export declare class FlowConfig {
    network: FlowNetwork;
    flowDir: string;
    constructor(options?: Partial<FlowConfig>);
}
export declare class FlowWrapper {
    config: FlowConfig;
    service: {
        address: string | null;
        key: string | null;
        keyId: number;
    };
    authz: any;
    private transactionLock;
    private transactionQueue;
    constructor(config?: Partial<FlowConfig>);
    getAccessNode(network: FlowNetwork): "https://rest-mainnet.onflow.org" | "https://rest-testnet.onflow.org" | "http://127.0.0.1:8888";
    loadFlowConfig(): void;
    loadServiceAccount(flowDir: string): {
        address: string;
        key: string;
        keyId: number;
        signatureAlgorithm: string;
        hashAlgorithm: string;
    };
    loadAccountByName(accountName: string, flowDir: string): {
        address: string;
        key: string;
        keyId: number;
        signatureAlgorithm: string;
        hashAlgorithm: string;
    };
    authzFactory(address: string, keyId: number, privateKey: string, signatureAlgorithm?: string, hashAlgorithm?: string): (account: any) => Promise<any>;
    executeScript(scriptPath: string, args?: any[], proposerWalletId?: string): Promise<FlowResult>;
    sendTransaction(transactionPath: string, args?: any[], roles?: {
        proposer?: any;
        payer?: any;
        authorizer?: any | any[];
    }, privateKeys?: any, proposerWalletId?: string, payerWalletId?: string, authorizerWalletIds?: string[]): Promise<unknown>;
    private _processTransactionQueue;
    private _executeTransaction;
    private _buildFclArgs;
    private _isValidWalletId;
    private _createTransactionRecord;
    private _updateTransactionSuccess;
    private _updateTransactionFailure;
    private _updateTransactionStatus;
    private _updateTransactionSealed;
    private _extractBlockchainData;
    private _setupTransactionRoles;
    getAccount(address: string): Promise<FlowResult>;
    getTransaction(transactionId: string): Promise<FlowResult>;
    waitForTransactionSeal(transactionId: string, timeout?: number): Promise<FlowResult>;
    updateConfig(options: Partial<FlowConfig>): void;
    getTransactionHistory(walletId: string, limit?: number): Promise<Transaction[]>;
    getTransactionById(transactionId: string): Promise<Transaction>;
    getTransactionByFlowId(flowTransactionId: string): Promise<Transaction>;
    addTransactionLog(transactionId: string, logEntry: any): Promise<boolean>;
    updateTransactionStatus(transactionId: string, status: Transaction['status'], additionalData?: Partial<Transaction>): Promise<Transaction>;
}
export declare function createFlowWrapper(network?: FlowNetwork | string, options?: Partial<FlowConfig>): FlowWrapper;
export declare function executeScript(scriptPath: string, args?: any[], network?: FlowNetwork | string, options?: Partial<FlowConfig>): Promise<FlowResult>;
export declare function sendTransaction(transactionPath: string, args?: any[], roles?: {
    proposer?: any;
    payer?: any;
    authorizer?: any | any[];
}, network?: FlowNetwork | string, options?: Partial<FlowConfig>): Promise<unknown>;
