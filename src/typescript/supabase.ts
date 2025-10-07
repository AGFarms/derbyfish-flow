import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Validate required environment variables
if (!SUPABASE_URL) {
    console.warn("WARNING: SUPABASE_URL environment variable not set");
}
if (!SUPABASE_ANON_KEY) {
    console.warn("WARNING: SUPABASE_ANON_KEY environment variable not set");
}
if (!SUPABASE_SERVICE_KEY) {
    console.warn("WARNING: SUPABASE_SERVICE_ROLE_KEY environment variable not set - server-side operations may not work");
}

// Initialize Supabase client with service role key for server-side operations
// This bypasses RLS policies for server-side operations
export const supabase: SupabaseClient | null = SUPABASE_URL && SUPABASE_SERVICE_KEY 
    ? createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    : null;

// Transaction interface matching the database schema
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

// Transaction logging class
export class TransactionLogger {
    private supabase: SupabaseClient | null;

    constructor() {
        this.supabase = supabase;
    }

    async createTransaction(transactionData: Partial<Transaction>): Promise<Transaction | null> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - transaction not logged");
            return null;
        }

        try {
            const { data, error } = await this.supabase
                .from('transactions')
                .insert([transactionData])
                .select()
                .single();

            if (error) {
                console.error('Error creating transaction:', error);
                return null;
            }

            return data;
        } catch (error) {
            console.error('Error creating transaction:', error);
            return null;
        }
    }

    async updateTransaction(id: string, updates: Partial<Transaction>): Promise<Transaction | null> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - transaction not updated");
            return null;
        }

        try {
            const { data, error } = await this.supabase
                .from('transactions')
                .update(updates)
                .eq('id', id)
                .select()
                .single();

            if (error) {
                console.error('Error updating transaction:', error);
                return null;
            }

            return data;
        } catch (error) {
            console.error('Error updating transaction:', error);
            return null;
        }
    }

    async updateTransactionByFlowId(flowTransactionId: string, updates: Partial<Transaction>): Promise<Transaction | null> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - transaction not updated");
            return null;
        }

        try {
            const { data, error } = await this.supabase
                .from('transactions')
                .update(updates)
                .eq('flow_transaction_id', flowTransactionId)
                .select()
                .single();

            if (error) {
                console.error('Error updating transaction by Flow ID:', error);
                return null;
            }

            return data;
        } catch (error) {
            console.error('Error updating transaction by Flow ID:', error);
            return null;
        }
    }

    async getTransaction(id: string): Promise<Transaction | null> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - cannot fetch transaction");
            return null;
        }

        try {
            const { data, error } = await this.supabase
                .from('transactions')
                .select('*')
                .eq('id', id)
                .single();

            if (error) {
                console.error('Error fetching transaction:', error);
                return null;
            }

            return data;
        } catch (error) {
            console.error('Error fetching transaction:', error);
            return null;
        }
    }

    async getTransactionByFlowId(flowTransactionId: string): Promise<Transaction | null> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - cannot fetch transaction");
            return null;
        }

        try {
            const { data, error } = await this.supabase
                .from('transactions')
                .select('*')
                .eq('flow_transaction_id', flowTransactionId)
                .single();

            if (error) {
                console.error('Error fetching transaction by Flow ID:', error);
                return null;
            }

            return data;
        } catch (error) {
            console.error('Error fetching transaction by Flow ID:', error);
            return null;
        }
    }

    async getTransactionsByWallet(walletId: string, limit: number = 50): Promise<Transaction[]> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - cannot fetch transactions");
            return [];
        }

        try {
            const { data, error } = await this.supabase
                .from('transactions')
                .select('*')
                .or(`proposer_wallet_id.eq.${walletId},payer_wallet_id.eq.${walletId},authorizer_wallet_ids.cs.{${walletId}}`)
                .order('created_at', { ascending: false })
                .limit(limit);

            if (error) {
                console.error('Error fetching transactions by wallet:', error);
                return [];
            }

            return data || [];
        } catch (error) {
            console.error('Error fetching transactions by wallet:', error);
            return [];
        }
    }

    async addLog(transactionId: string, logEntry: any): Promise<boolean> {
        if (!this.supabase) {
            console.warn("Supabase client not initialized - log not added");
            return false;
        }

        try {
            // First get the current transaction to append to existing logs
            const transaction = await this.getTransaction(transactionId);
            if (!transaction) {
                console.error('Transaction not found for log addition');
                return false;
            }

            const currentLogs = transaction.logs || [];
            const newLogs = [...currentLogs, {
                ...logEntry,
                timestamp: new Date().toISOString()
            }];

            const { error } = await this.supabase
                .from('transactions')
                .update({ logs: newLogs })
                .eq('id', transactionId);

            if (error) {
                console.error('Error adding log to transaction:', error);
                return false;
            }

            return true;
        } catch (error) {
            console.error('Error adding log to transaction:', error);
            return false;
        }
    }
}

// Export singleton instance
export const transactionLogger = new TransactionLogger();
