import { FlowNetwork, FlowResultOptions } from './types';
export declare class FlowResult {
    success: boolean;
    data: any;
    errorMessage: string;
    transactionId: string | null;
    constructor(options?: FlowResultOptions);
    toDict(): {
        success: boolean;
        data: any;
        errorMessage: string;
        transactionId: string;
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
    executeScript(scriptPath: string, args?: any[]): Promise<{
        success: boolean;
        data: any;
        errorMessage?: undefined;
    } | {
        success: boolean;
        errorMessage: any;
        data: any;
    }>;
    sendTransaction(transactionPath: string, args?: any[], roles?: {
        proposer?: any;
        payer?: any;
        authorizer?: any | any[];
    }): Promise<{
        success: boolean;
        errorMessage: string;
        transactionId?: undefined;
        data?: undefined;
    } | {
        success: boolean;
        transactionId: any;
        data: any;
        errorMessage?: undefined;
    } | {
        success: boolean;
        errorMessage: any;
        transactionId: any;
        data: any;
    }>;
    getAccount(address: string): Promise<FlowResult>;
    getTransaction(transactionId: string): Promise<FlowResult>;
    waitForTransactionSeal(transactionId: string, timeout?: number): Promise<FlowResult>;
    updateConfig(options: Partial<FlowConfig>): void;
}
export declare function createFlowWrapper(network?: FlowNetwork | string, options?: Partial<FlowConfig>): FlowWrapper;
export declare function executeScript(scriptPath: string, args?: any[], network?: FlowNetwork | string, options?: Partial<FlowConfig>): Promise<{
    success: boolean;
    data: any;
    errorMessage?: undefined;
} | {
    success: boolean;
    errorMessage: any;
    data: any;
}>;
export declare function sendTransaction(transactionPath: string, args?: any[], roles?: {
    proposer?: any;
    payer?: any;
    authorizer?: any | any[];
}, network?: FlowNetwork | string, options?: Partial<FlowConfig>): Promise<{
    success: boolean;
    errorMessage: string;
    transactionId?: undefined;
    data?: undefined;
} | {
    success: boolean;
    transactionId: any;
    data: any;
    errorMessage?: undefined;
} | {
    success: boolean;
    errorMessage: any;
    transactionId: any;
    data: any;
}>;
