-- Migration: Create transactions table for Flow transaction tracking
-- Description: Create a comprehensive transactions table to track all Flow blockchain transactions with status updates and logging

-- Create transactions table
CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "flow_transaction_id" "text" UNIQUE,
    "transaction_type" "text" NOT NULL CHECK ("transaction_type" IN ('script', 'transaction', 'mint', 'burn', 'transfer', 'swap')),
    "status" "text" DEFAULT 'pending' NOT NULL CHECK ("status" IN ('pending', 'submitted', 'sealed', 'executed', 'failed', 'expired')),
    "proposer_wallet_id" "uuid" REFERENCES "public"."wallet"("id") ON DELETE SET NULL,
    "payer_wallet_id" "uuid" REFERENCES "public"."wallet"("id") ON DELETE SET NULL,
    "authorizer_wallet_ids" "uuid"[] DEFAULT '{}',
    "script_path" "text",
    "transaction_path" "text",
    "arguments" "jsonb" DEFAULT '{}',
    "network" "text" DEFAULT 'mainnet' NOT NULL,
    "block_height" BIGINT,
    "block_timestamp" timestamp with time zone,
    "gas_used" BIGINT,
    "gas_limit" BIGINT,
    "error_message" "text",
    "logs" "jsonb" DEFAULT '[]',
    "result_data" "jsonb",
    "execution_time_ms" INTEGER,
    "retry_count" INTEGER DEFAULT 0,
    "notes" "text"
);

-- Add primary key
ALTER TABLE "public"."transactions" ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");

-- Add indexes for performance
CREATE INDEX "idx_transactions_flow_transaction_id" ON "public"."transactions" ("flow_transaction_id");
CREATE INDEX "idx_transactions_proposer_wallet_id" ON "public"."transactions" ("proposer_wallet_id");
CREATE INDEX "idx_transactions_payer_wallet_id" ON "public"."transactions" ("payer_wallet_id");
CREATE INDEX "idx_transactions_status" ON "public"."transactions" ("status");
CREATE INDEX "idx_transactions_created_at" ON "public"."transactions" ("created_at");
CREATE INDEX "idx_transactions_transaction_type" ON "public"."transactions" ("transaction_type");
CREATE INDEX "idx_transactions_network" ON "public"."transactions" ("network");
CREATE INDEX "idx_transactions_authorizer_wallet_ids" ON "public"."transactions" USING GIN ("authorizer_wallet_ids");

-- Add comments
COMMENT ON TABLE "public"."transactions" IS 'Tracks all Flow blockchain transactions with comprehensive status and logging';
COMMENT ON COLUMN "public"."transactions"."flow_transaction_id" IS 'Flow blockchain transaction ID (unique)';
COMMENT ON COLUMN "public"."transactions"."transaction_type" IS 'Type of transaction: script, transaction, mint, burn, transfer, swap';
COMMENT ON COLUMN "public"."transactions"."status" IS 'Transaction status: pending, submitted, sealed, executed, failed, expired';
COMMENT ON COLUMN "public"."transactions"."proposer_wallet_id" IS 'Wallet ID of the transaction proposer';
COMMENT ON COLUMN "public"."transactions"."payer_wallet_id" IS 'Wallet ID of the transaction payer';
COMMENT ON COLUMN "public"."transactions"."authorizer_wallet_ids" IS 'Array of wallet IDs that authorized the transaction';
COMMENT ON COLUMN "public"."transactions"."script_path" IS 'Path to the Cadence script file (for script transactions)';
COMMENT ON COLUMN "public"."transactions"."transaction_path" IS 'Path to the Cadence transaction file (for transaction types)';
COMMENT ON COLUMN "public"."transactions"."arguments" IS 'JSON arguments passed to the script/transaction';
COMMENT ON COLUMN "public"."transactions"."network" IS 'Flow network (mainnet, testnet, emulator)';
COMMENT ON COLUMN "public"."transactions"."block_height" IS 'Flow blockchain block height when transaction was included';
COMMENT ON COLUMN "public"."transactions"."block_timestamp" IS 'Flow blockchain block timestamp';
COMMENT ON COLUMN "public"."transactions"."gas_used" IS 'Gas units consumed by the transaction';
COMMENT ON COLUMN "public"."transactions"."gas_limit" IS 'Gas limit set for the transaction';
COMMENT ON COLUMN "public"."transactions"."error_message" IS 'Error message if transaction failed';
COMMENT ON COLUMN "public"."transactions"."logs" IS 'Array of transaction logs and events';
COMMENT ON COLUMN "public"."transactions"."result_data" IS 'Result data returned from the transaction';
COMMENT ON COLUMN "public"."transactions"."execution_time_ms" IS 'Transaction execution time in milliseconds';
COMMENT ON COLUMN "public"."transactions"."retry_count" IS 'Number of retry attempts for failed transactions';
COMMENT ON COLUMN "public"."transactions"."notes" IS 'Additional notes about the transaction';

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION "public"."update_transactions_updated_at"() RETURNS "trigger"
LANGUAGE "plpgsql"
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Create trigger to automatically update updated_at
CREATE OR REPLACE TRIGGER "trigger_update_transactions_updated_at"
    BEFORE UPDATE ON "public"."transactions"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_transactions_updated_at"();

-- Enable RLS (Row Level Security)
ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "transactions_read_policy" ON "public"."transactions"
    FOR SELECT USING (
        -- Users can read transactions where they are the proposer, payer, or authorizer
        proposer_wallet_id IN (
            SELECT id FROM public.wallet WHERE auth_id = auth.uid()
        ) OR
        payer_wallet_id IN (
            SELECT id FROM public.wallet WHERE auth_id = auth.uid()
        ) OR
        auth.uid()::text = ANY(
            SELECT auth_id::text FROM public.wallet WHERE id = ANY(authorizer_wallet_ids)
        )
    );

CREATE POLICY "transactions_insert_policy" ON "public"."transactions"
    FOR INSERT WITH CHECK (
        -- Users can insert transactions where they are the proposer
        proposer_wallet_id IN (
            SELECT id FROM public.wallet WHERE auth_id = auth.uid()
        )
    );

CREATE POLICY "transactions_update_policy" ON "public"."transactions"
    FOR UPDATE USING (
        -- Users can update transactions where they are the proposer, payer, or authorizer
        proposer_wallet_id IN (
            SELECT id FROM public.wallet WHERE auth_id = auth.uid()
        ) OR
        payer_wallet_id IN (
            SELECT id FROM public.wallet WHERE auth_id = auth.uid()
        ) OR
        auth.uid()::text = ANY(
            SELECT auth_id::text FROM public.wallet WHERE id = ANY(authorizer_wallet_ids)
        )
    );

-- Add a comment to document this migration
COMMENT ON TABLE public.transactions IS 'Transactions table created for Flow transaction tracking - 2025-01-20. Tracks all Flow blockchain transactions with comprehensive status updates, logging, and wallet relationships.';
