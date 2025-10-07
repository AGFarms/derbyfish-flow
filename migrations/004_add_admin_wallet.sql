

-- Now create the admin wallet entry
INSERT INTO "public"."wallet" ("id", "created_at", "auth_id", "flow_address", "flow_private_key", "flow_public_key")
VALUES (
    '77ef3a77-19e8-49d9-bcc7-f89872378622'::uuid,
    NOW(),
    '77ef3a77-19e8-49d9-bcc7-f89872378622'::uuid,  -- References the admin user we just created
    'ed2202de80195438',  -- Admin wallet Flow address
    NULL,  -- Private key is managed separately in flow.json
    NULL   -- Public key can be added later if needed
) ON CONFLICT (id) DO NOTHING;

-- Add a comment to document this special wallet
COMMENT ON TABLE "public"."wallet" IS 'User wallets including custodial Flow blockchain wallets. RLS policies ensure users can only access their own wallet data. Private keys are stored securely and only accessible by the wallet owner. Special admin wallet (id: 00000000-0000-0000-0000-000000000002) is used for system transactions.';
