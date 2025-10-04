-- Migration: Clear wallet table and remove unnecessary columns
-- Description: Clear all data from the wallet table and remove redundant columns to prepare for Flow account migration

-- Clear all existing wallet data
DELETE FROM public.wallet;

-- Remove unnecessary and duplicate columns
-- Keeping only essential columns: id, created_at, auth_id, flow_address, flow_private_key, flow_public_key
ALTER TABLE public.wallet DROP COLUMN IF EXISTS balance;
ALTER TABLE public.wallet DROP COLUMN IF EXISTS flow_seed_phrase;
ALTER TABLE public.wallet DROP COLUMN IF EXISTS flow_account_key;
ALTER TABLE public.wallet DROP COLUMN IF EXISTS wallet_type;
ALTER TABLE public.wallet DROP COLUMN IF EXISTS is_active;
ALTER TABLE public.wallet DROP COLUMN IF EXISTS last_sync_at;
ALTER TABLE public.wallet DROP COLUMN IF EXISTS address;

-- Reset the sequence if it exists (optional, depending on your setup)
-- ALTER SEQUENCE public.wallet_id_seq RESTART WITH 1;

-- Add a comment to document this migration
COMMENT ON TABLE public.wallet IS 'Wallet table cleared and simplified for Flow account migration - 2025-10-03. Removed redundant columns: balance, flow_seed_phrase, flow_account_key, wallet_type, is_active, last_sync_at, address';
