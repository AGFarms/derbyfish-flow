-- Migration to fix wallet RLS policies
-- The issue is that we have conflicting policies that prevent proper access

-- First, let's drop the conflicting policies
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."wallet";
DROP POLICY IF EXISTS "Users can view their own wallet" ON "public"."wallet";
DROP POLICY IF EXISTS "Users can update their own wallet" ON "public"."wallet";

-- Enable RLS on the wallet table if not already enabled
ALTER TABLE "public"."wallet" ENABLE ROW LEVEL SECURITY;

-- Create a new policy that allows users to read their own wallet data
-- This policy allows both authenticated and anon users to read their own wallet
CREATE POLICY "Users can read their own wallet" ON "public"."wallet"
    FOR SELECT 
    USING (auth.uid() = auth_id);

-- Create a policy that allows users to update their own wallet data
-- This policy is restricted to authenticated users only for security
CREATE POLICY "Users can update their own wallet" ON "public"."wallet"
    FOR UPDATE 
    TO authenticated
    USING (auth.uid() = auth_id) 
    WITH CHECK (auth.uid() = auth_id);

-- Create a policy that allows users to insert their own wallet data
-- This policy is restricted to authenticated users only for security
CREATE POLICY "Users can insert their own wallet" ON "public"."wallet"
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = auth_id);

-- Create a policy that allows users to delete their own wallet data
-- This policy is restricted to authenticated users only for security
CREATE POLICY "Users can delete their own wallet" ON "public"."wallet"
    FOR DELETE 
    TO authenticated
    USING (auth.uid() = auth_id);

-- Add a comment explaining the security model
COMMENT ON TABLE "public"."wallet" IS 'User wallets including custodial Flow blockchain wallets. RLS policies ensure users can only access their own wallet data. Private keys are stored securely and only accessible by the wallet owner.';
