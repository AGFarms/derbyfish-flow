"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.transactionLogger = exports.TransactionLogger = exports.supabase = void 0;
const supabase_js_1 = require("@supabase/supabase-js");
const dotenv_1 = __importDefault(require("dotenv"));
// Load environment variables
dotenv_1.default.config();
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
exports.supabase = SUPABASE_URL && SUPABASE_SERVICE_KEY
    ? (0, supabase_js_1.createClient)(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    : null;
// Transaction logging class
class TransactionLogger {
    constructor() {
        this.supabase = exports.supabase;
    }
    async createTransaction(transactionData) {
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
        }
        catch (error) {
            console.error('Error creating transaction:', error);
            return null;
        }
    }
    async updateTransaction(id, updates) {
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
        }
        catch (error) {
            console.error('Error updating transaction:', error);
            return null;
        }
    }
    async updateTransactionByFlowId(flowTransactionId, updates) {
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
        }
        catch (error) {
            console.error('Error updating transaction by Flow ID:', error);
            return null;
        }
    }
    async getTransaction(id) {
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
        }
        catch (error) {
            console.error('Error fetching transaction:', error);
            return null;
        }
    }
    async getTransactionByFlowId(flowTransactionId) {
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
        }
        catch (error) {
            console.error('Error fetching transaction by Flow ID:', error);
            return null;
        }
    }
    async getTransactionsByWallet(walletId, limit = 50) {
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
        }
        catch (error) {
            console.error('Error fetching transactions by wallet:', error);
            return [];
        }
    }
    async addLog(transactionId, logEntry) {
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
        }
        catch (error) {
            console.error('Error adding log to transaction:', error);
            return false;
        }
    }
}
exports.TransactionLogger = TransactionLogger;
// Export singleton instance
exports.transactionLogger = new TransactionLogger();
