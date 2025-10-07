const fastify = require('fastify')({ logger: true });
const jwt = require('jsonwebtoken');
const { createClient } = require('@supabase/supabase-js');
const { config } = require('dotenv');
const { FlowWrapper } = require('./flowWrapper');
const { v4: uuidv4 } = require('uuid');
const fcl = require('@onflow/fcl');
const sdk = require('@onflow/sdk');

// Load environment variables
config();

console.log("🚀 Starting DerbyFish Flow API Server with Fastify...");
console.log(`📅 Server start time: ${new Date().toISOString()}`);
console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);

// Supabase configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET;

// Validate required environment variables
console.log("🔍 Validating environment variables...");
if (!SUPABASE_URL) {
    console.log("⚠️  WARNING: SUPABASE_URL environment variable not set");
} else {
    console.log("✅ SUPABASE_URL configured");
}
if (!SUPABASE_ANON_KEY) {
    console.log("⚠️  WARNING: SUPABASE_ANON_KEY environment variable not set");
} else {
    console.log("✅ SUPABASE_ANON_KEY configured");
}
if (!SUPABASE_SERVICE_KEY) {
    console.log("⚠️  WARNING: SUPABASE_SERVICE_ROLE_KEY environment variable not set - server-side operations may not work");
} else {
    console.log("✅ SUPABASE_SERVICE_ROLE_KEY configured");
}
if (!SUPABASE_JWT_SECRET) {
    console.log("⚠️  WARNING: SUPABASE_JWT_SECRET environment variable not set - JWT authentication will not work");
} else {
    console.log("✅ SUPABASE_JWT_SECRET configured");
}

// Initialize Supabase client with service role key for server-side operations
console.log("🔗 Initializing Supabase client...");
const supabase = SUPABASE_URL && SUPABASE_SERVICE_KEY 
    ? createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    : null;

if (supabase) {
    console.log("✅ Supabase client initialized successfully");
} else {
    console.log("❌ Supabase client initialization failed - server-side operations will not work");
}

// Global storage for background tasks
const backgroundTasks = {};
console.log("📦 Background tasks storage initialized");

// Initialize Flow wrapper
console.log("⚡ Initializing Flow wrapper...");
const flowWrapper = new FlowWrapper({
    network: 'mainnet',
    flowDir: './flow',
    timeout: 300,
    maxRetries: 3,
    rateLimitDelay: 0.2,
    jsonOutput: true
});
console.log("✅ Flow wrapper initialized successfully");

// Configure FCL
console.log("⚡ Configuring FCL...");
fcl.config({
    "accessNode.api": "https://rest-mainnet.onflow.org",
    "discovery.wallet": "https://fcl-discovery.onflow.org/authn",
    "0x7e60df042a9c0868": "0x7e60df042a9c0868", // FlowToken
    "0x1654653399040a61": "0x1654653399040a61", // FungibleToken
    "0x1d4e194192246d83": "0x1d4e194192246d83", // FUSD
    "0x2d4c3caffbeab845": "0x2d4c3caffbeab845", // BaitCoin
});
console.log("✅ FCL configured successfully");

async function verifySupabaseAuth(authHeader, requestId = 'unknown') {
    console.log(`🔐 Starting Supabase authentication... [${requestId}]`);
    try {
        if (!SUPABASE_JWT_SECRET) {
            console.log("❌ WARNING: SUPABASE_JWT_SECRET not configured");
            return null;
        }
        
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            console.log("❌ Invalid authorization header format");
            return null;
        }
        
        const token = authHeader.split(' ')[1];
        if (!token) {
            console.log("❌ No token found in authorization header");
            return null;
        }
        
        console.log("🔍 Verifying JWT token locally...");
        console.log(`🔍 Token length: ${token.length} [${requestId}]`);
        
        // Verify JWT locally - this is the proper server-side approach
        const payload = jwt.verify(token, SUPABASE_JWT_SECRET, {
            algorithms: ['HS256'],
            ignoreExpiration: false,
            ignoreNotBefore: false
        });
        
        console.log(`🔍 JWT verification completed [${requestId}]`);
        
        if (!payload.sub) {
            console.log("❌ JWT token missing 'sub' claim");
            return null;
        }
        
        // Check if token is expired
        const currentTime = Math.floor(Date.now() / 1000);
        if (payload.exp < currentTime) {
            console.log("❌ JWT token has expired");
            return null;
        }
        
        // Create a user object that matches Supabase's user structure
        const user = {
            id: payload.sub,
            email: payload.email,
            created_at: payload.iat ? new Date(payload.iat * 1000).toISOString() : null,
            aud: payload.aud,
            role: payload.role
        };
        
        console.log(`✅ JWT authentication successful for user: ${user.id}`);
        return user;
        
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            console.log("❌ JWT token has expired");
        } else if (error.name === 'JsonWebTokenError') {
            console.log("❌ JWT token has invalid signature");
        } else {
            console.log(`❌ Authentication error: ${error.message}`);
        }
        return null;
    }
}

async function getWalletDetails(userId, requestId = 'unknown') {
    console.log(`🔍 Fetching wallet details for user: ${userId} [${requestId}]`);
    try {
        if (!supabase) {
            console.log("❌ WARNING: Supabase client not configured");
            return null;
        }
            
        console.log(`📊 Querying wallet table for auth_id: ${userId} [${requestId}]`);
        
        // Create a timeout promise
        const timeoutPromise = new Promise((_, reject) => {
            setTimeout(() => reject(new Error('Database query timeout after 2 seconds')), 2000);
        });
        
        // Create the database query promise
        console.log(`📊 Starting database query... [${requestId}]`);
        const queryPromise = supabase
            .from('wallet')
            .select('*')
            .eq('auth_id', userId)
            .limit(1);
        
        // Race between query and timeout
        const { data, error } = await Promise.race([queryPromise, timeoutPromise]);
        console.log(`📊 Database query completed [${requestId}]`);
        
        if (error) {
            console.log(`❌ Supabase error: ${error.message} [${requestId}]`);
            return null;
        }
        
        if (data && data.length > 0) {
            const walletData = data[0];
            console.log(`✅ Found wallet for user ${userId}: ${walletData.address || walletData.flow_address || 'no address'} [${requestId}]`);
            return walletData;
        } else {
            console.log(`⚠️  No wallet found for auth_id: ${userId} [${requestId}]`);
            return null;
        }
    } catch (error) {
        if (error.message.includes('timeout')) {
            console.log(`❌ Database query timeout: ${error.message} [${requestId}]`);
        } else {
            console.log(`❌ Error fetching wallet details: ${error.message} [${requestId}]`);
        }
        return null;
    }
}

function getWalletAddress(walletDetails) {
    if (!walletDetails) {
        return null;
    }
    // Try both possible address fields from the wallet table
    return walletDetails.address || walletDetails.flow_address;
}

function logAuthenticatedUser(user, walletDetails) {
    const userId = user.id || 'unknown';
    const email = user.email || 'unknown';
    
    let walletAddress, walletType, isActive;
    if (walletDetails) {
        walletAddress = getWalletAddress(walletDetails) || 'no address';
        walletType = walletDetails.wallet_type || 'unknown';
        isActive = walletDetails.is_active || false;
    } else {
        walletAddress = 'no wallet';
        walletType = 'none';
        isActive = false;
    }
    
    console.log("=== AUTHENTICATED USER ===");
    console.log(`User ID: ${userId}`);
    console.log(`Email: ${email}`);
    console.log(`Wallet Address: ${walletAddress}`);
    console.log(`Wallet Type: ${walletType}`);
    console.log(`Wallet Active: ${isActive}`);
    console.log(`Timestamp: ${new Date().toISOString()}`);
    console.log("==========================");
}

// FCL transaction execution function
async function executeFlowTransaction(transactionCode, args = [], proposer, authorizers = [], payer, requestId = 'unknown') {
    console.log(`⚡ Executing Flow transaction with FCL... [${requestId}]`);
    console.log(`📋 Transaction: ${transactionCode}`);
    console.log(`📋 Args: ${JSON.stringify(args)}`);
    console.log(`📋 Proposer: ${proposer}`);
    console.log(`📋 Authorizers: ${JSON.stringify(authorizers)}`);
    console.log(`📋 Payer: ${payer}`);
    
    try {
        // Create the transaction
        const transaction = sdk.transaction(transactionCode);
        
        // Add arguments
        args.forEach(arg => {
            transaction.add(sdk.arg(arg, sdk.t.String));
        });
        
        // Set proposer
        transaction.setProposer(sdk.authorization(proposer, sdk.signer));
        
        // Set authorizers
        authorizers.forEach(auth => {
            transaction.addAuthorizer(sdk.authorization(auth, sdk.signer));
        });
        
        // Set payer
        transaction.setPayer(sdk.authorization(payer, sdk.signer));
        
        // Execute the transaction
        console.log(`🚀 Sending transaction to Flow network... [${requestId}]`);
        const result = await fcl.send(transaction);
        
        console.log(`⏳ Waiting for transaction to be sealed... [${requestId}]`);
        const sealed = await fcl.tx(result).onceSealed();
        
        console.log(`✅ Transaction sealed successfully [${requestId}]`);
        console.log(`📝 Transaction ID: ${sealed.id}`);
        
        return {
            success: true,
            transactionId: sealed.id,
            status: sealed.status,
            events: sealed.events,
            execution_time: Date.now() - Date.now() // This would need proper timing
        };
        
    } catch (error) {
        console.log(`❌ FCL transaction failed: ${error.message} [${requestId}]`);
        return {
            success: false,
            error: error.message,
            transactionId: null,
            execution_time: 0
        };
    }
}

// Authentication hook for Fastify
async function authenticate(request, reply) {
    const requestId = Math.random().toString(36).substr(2, 9);
    request.requestId = requestId;
    
    console.log(`🔐 Authentication hook called for: ${request.method} ${request.url} [${requestId}]`);
    
    try {
        // Get Authorization header
        const authHeader = request.headers.authorization;
        
        if (!authHeader) {
            console.log("❌ Authentication failed: No Authorization header provided");
            return reply.status(401).send({ error: 'Authorization header is required' });
        }
        
        // Verify with Supabase
        const user = await verifySupabaseAuth(authHeader, requestId);
        if (!user) {
            console.log("❌ Authentication failed: Supabase verification failed");
            return reply.status(401).send({ error: 'Invalid or expired token' });
        }
        
        // Get wallet details
        const walletDetails = await getWalletDetails(user.id, requestId);
        
        // Log the authenticated user
        logAuthenticatedUser(user, walletDetails);
        
        // Add user info to request for use in the endpoint
        request.user = user;
        request.walletDetails = walletDetails;
        
        console.log("✅ Authentication successful, proceeding to endpoint handler");
        
    } catch (error) {
        console.log(`❌ Authentication error: ${error.message}`);
        return reply.status(500).send({ error: 'Authentication failed due to server error' });
    }
}

// Test routes
fastify.post('/test-endpoint', async (request, reply) => {
    console.log("🧪 TEST ENDPOINT CALLED");
    console.log(`🆔 Request ID: ${request.requestId}`);
    return { message: 'Test endpoint working', requestId: request.requestId };
});

fastify.post('/test-send-bait', async (request, reply) => {
    console.log("🧪 TEST SEND BAIT ENDPOINT CALLED");
    console.log(`🆔 Request ID: ${request.requestId}`);
    console.log(`📦 Request Body: ${JSON.stringify(request.body)}`);
    return { 
        message: 'Test send-bait endpoint working', 
        requestId: request.requestId,
        body: request.body
    };
});

fastify.post('/test-auth-simple', async (request, reply) => {
    console.log("🔐 TEST AUTH SIMPLE ROUTE CALLED");
    const requestId = Math.random().toString(36).substr(2, 9);
    console.log(`🆔 Request ID: ${requestId}`);
    
    // Simple Supabase auth verification without database query
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return reply.status(401).send({ error: 'No valid auth header' });
    }
    
    try {
        const user = await verifySupabaseAuth(authHeader, requestId);
        if (!user) {
            return reply.status(401).send({ error: 'Invalid token' });
        }
        
        return { 
            message: 'Test auth simple route working', 
            requestId: requestId,
            user: user.id 
        };
    } catch (error) {
        return reply.status(401).send({ error: 'Invalid token' });
    }
});

// Main send-bait endpoint with authentication
fastify.post('/transactions/send-bait', { preHandler: authenticate }, async (request, reply) => {
    console.log("=== SEND BAIT ENDPOINT CALLED ===");
    console.log(`🆔 Request ID: ${request.requestId}`);
    console.log(`👤 User: ${request.user?.id}, Wallet: ${getWalletAddress(request.walletDetails)}`);
    
    const data = request.body || {};
    const toAddress = data.to_address;
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    console.log(`📋 Request data: amount=${amount}, to_address=${toAddress}, network=${network}`);
    
    if (!amount) {
        return reply.status(400).send({ error: 'amount parameter is required' });
    }
    
    // Use authenticated user's wallet address as default if not specified
    if (!toAddress) {
        const userAddress = getWalletAddress(request.walletDetails);
        if (userAddress) {
            console.log(`Using authenticated user's wallet address: ${userAddress}`);
        } else {
            return reply.status(400).send({ error: 'to_address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Get user ID for Flow account name
    const userId = request.user.id;
    if (!userId) {
        return reply.status(400).send({ error: 'No user ID found in token' });
    }
    
    // Read the Cadence transaction code
    const fs = require('fs');
    const path = require('path');
    const transactionPath = path.join(__dirname, 'flow', 'cadence', 'transactions', 'sendBait.cdc');
    
    let transactionCode;
    try {
        transactionCode = fs.readFileSync(transactionPath, 'utf8');
        console.log(`📄 Loaded transaction code from: ${transactionPath}`);
    } catch (error) {
        console.log(`❌ Failed to read transaction file: ${error.message}`);
        return reply.status(500).send({ 
            error: 'Failed to read transaction file',
            details: error.message 
        });
    }
    
    // Use FCL for transaction execution
    const result = await executeFlowTransaction(
        transactionCode,
        [toAddress, amount],
        'mainnet-agfarms', // Proposer
        ['mainnet-agfarms', userId], // Authorizers
        'mainnet-agfarms', // Payer
        request.requestId
    );
    
    return {
        success: result.success,
        transaction_id: result.transactionId,
        status: result.status,
        events: result.events,
        execution_time: result.execution_time,
        error: result.error || null
    };
});

// Health check endpoint
fastify.get('/health', async (request, reply) => {
    const activeTasks = Object.values(backgroundTasks).filter(task => task.status === 'running').length;
    return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        active_tasks: activeTasks
    };
});

// Root endpoint
fastify.get('/', async (request, reply) => {
    return {
        message: 'Flow CLI HTTP Wrapper - Fastify Version',
        version: '1.0.2',
        endpoints: {
            test: {
                test_endpoint: 'POST /test-endpoint - Test basic routing',
                test_send_bait: 'POST /test-send-bait - Test send-bait without auth',
                test_auth_simple: 'POST /test-auth-simple - Test auth without database'
            },
            transactions: {
                send_bait: 'POST /transactions/send-bait - Send BAIT tokens'
            },
            health: {
                health_check: 'GET /health - Health check'
            }
        }
    };
});

// Start the server
const start = async () => {
    try {
        const PORT = process.env.PORT || 5000;
        await fastify.listen({ port: PORT, host: '0.0.0.0' });
        console.log("🎉 ==========================================");
        console.log("🎉 DerbyFish Flow API Server Started with Fastify!");
        console.log("🎉 ==========================================");
        console.log(`🌐 Server running on: http://0.0.0.0:${PORT}`);
        console.log(`📅 Start time: ${new Date().toISOString()}`);
        console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);
        console.log(`⚡ Flow network: ${flowWrapper.config.network}`);
        console.log(`📊 Active background tasks: ${Object.keys(backgroundTasks).length}`);
        console.log("🎉 ==========================================");
        console.log("📚 Available endpoints:");
        console.log("   GET  / - API documentation");
        console.log("   GET  /health - Health check");
        console.log("   POST /test-endpoint - Test basic routing");
        console.log("   POST /test-send-bait - Test send-bait without auth");
        console.log("   POST /test-auth-simple - Test auth without database");
        console.log("   POST /transactions/send-bait - Send BAIT tokens");
        console.log("🎉 ==========================================");
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};

start();
