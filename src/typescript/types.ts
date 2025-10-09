export enum FlowOperationType {
    SCRIPT = "script",
    TRANSACTION = "transaction",
    ACCOUNT = "account",
    BLOCK = "block"
}

export enum FlowNetwork {
    MAINNET = "mainnet",
    TESTNET = "testnet",
    EMULATOR = "emulator"
}

export interface FlowResultOptions {
    success?: boolean;
    data?: any;
    errorMessage?: string;
    transactionId?: string | null;
    executionTime?: number;
    blockHeight?: number | null;
    blockTimestamp?: string | null;
    gasUsed?: number | null;
}