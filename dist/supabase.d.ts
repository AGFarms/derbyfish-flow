import { SupabaseClient } from '@supabase/supabase-js';
export declare const supabase: SupabaseClient | null;
export interface Transaction {
    id?: string;
    created_at?: string;
    updated_at?: string;
    flow_transaction_id?: string;
    transaction_type: 'script' | 'transaction' | 'mint' | 'burn' | 'transfer' | 'swap';
    status: 'pending' | 'submitted' | 'sealed' | 'executed' | 'failed' | 'expired';
    proposer_wallet_id?: string;
    payer_wallet_id?: string;
    authorizer_wallet_ids?: string[];
    script_path?: string;
    transaction_path?: string;
    arguments?: any;
    network: string;
    block_height?: number;
    block_timestamp?: string;
    gas_used?: number;
    gas_limit?: number;
    error_message?: string;
    logs?: any[];
    result_data?: any;
    execution_time_ms?: number;
    retry_count?: number;
    notes?: string;
}
export declare class TransactionLogger {
    private supabase;
    constructor();
    createTransaction(transactionData: Partial<Transaction>): Promise<Transaction | null>;
    updateTransaction(id: string, updates: Partial<Transaction>): Promise<Transaction | null>;
    updateTransactionByFlowId(flowTransactionId: string, updates: Partial<Transaction>): Promise<Transaction | null>;
    getTransaction(id: string): Promise<Transaction | null>;
    getTransactionByFlowId(flowTransactionId: string): Promise<Transaction | null>;
    getTransactionsByWallet(walletId: string, limit?: number): Promise<Transaction[]>;
    addLog(transactionId: string, logEntry: any): Promise<boolean>;
}
export declare const transactionLogger: TransactionLogger;
