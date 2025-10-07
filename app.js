const express = require('express');
const jwt = require('jsonwebtoken');
const { createClient } = require('@supabase/supabase-js');
const { createServerClient } = require('@supabase/ssr');
const { config } = require('dotenv');
const { FlowWrapper } = require('./flowWrapper');
const { v4: uuidv4 } = require('uuid');

// Load environment variables
config();

console.log("🚀 Starting DerbyFish Flow API Server...");
console.log(`📅 Server start time: ${new Date().toISOString()}`);
console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);

const app = express();
app.use(express.json());

// Add comprehensive request logging middleware
app.use((req, res, next) => {
    const startTime = Date.now();
    const requestId = Math.random().toString(36).substr(2, 9);
    
    // Log incoming request
    console.log("🌐 ==========================================");
    console.log(`📥 INCOMING REQUEST [${requestId}]`);
    console.log("🌐 ==========================================");
    console.log(`⏰ Timestamp: ${new Date().toISOString()}`);
    console.log(`🔗 Method: ${req.method}`);
    console.log(`📍 Path: ${req.path}`);
    console.log(`🔍 Full URL: ${req.protocol}://${req.get('host')}${req.originalUrl}`);
    console.log(`🌍 Remote IP: ${req.ip || req.connection.remoteAddress || req.socket.remoteAddress}`);
    console.log(`👤 User-Agent: ${req.get('User-Agent') || 'Not provided'}`);
    console.log(`🔑 Authorization: ${req.get('Authorization') ? 'Present' : 'Not provided'}`);
    console.log(`📋 Content-Type: ${req.get('Content-Type') || 'Not provided'}`);
    console.log(`📏 Content-Length: ${req.get('Content-Length') || 'Not provided'}`);
    
    // Log query parameters
    if (Object.keys(req.query).length > 0) {
        console.log(`🔍 Query Parameters: ${JSON.stringify(req.query, null, 2)}`);
    } else {
        console.log(`🔍 Query Parameters: None`);
    }
    
    // Log headers (excluding sensitive ones)
    const safeHeaders = { ...req.headers };
    if (safeHeaders.authorization) {
        safeHeaders.authorization = 'Bearer [REDACTED]';
    }
    console.log(`📋 Headers: ${JSON.stringify(safeHeaders, null, 2)}`);
    
    // Log body for POST/PUT requests (but limit size for security)
    if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
        if (req.body && Object.keys(req.body).length > 0) {
            const bodyStr = JSON.stringify(req.body, null, 2);
            if (bodyStr.length > 1000) {
                console.log(`📦 Request Body: ${bodyStr.substring(0, 1000)}... [TRUNCATED]`);
            } else {
                console.log(`📦 Request Body: ${bodyStr}`);
            }
        } else {
            console.log(`📦 Request Body: Empty`);
        }
    }
    
    console.log("🌐 ==========================================");
    
    // Set request ID for tracking
    req.requestId = requestId;
    
    // Override res.json to log response
    const originalJson = res.json;
    res.json = function(data) {
        const endTime = Date.now();
        const duration = endTime - startTime;
        
        console.log("📤 ==========================================");
        console.log(`📤 OUTGOING RESPONSE [${requestId}]`);
        console.log("📤 ==========================================");
        console.log(`⏰ Timestamp: ${new Date().toISOString()}`);
        console.log(`⏱️  Duration: ${duration}ms`);
        console.log(`📊 Status Code: ${res.statusCode}`);
        console.log(`📋 Response Headers: ${JSON.stringify(res.getHeaders(), null, 2)}`);
        
        if (data) {
            const responseStr = JSON.stringify(data, null, 2);
            if (responseStr.length > 1000) {
                console.log(`📦 Response Body: ${responseStr.substring(0, 1000)}... [TRUNCATED]`);
            } else {
                console.log(`📦 Response Body: ${responseStr}`);
            }
        } else {
            console.log(`📦 Response Body: Empty`);
        }
        
        console.log("📤 ==========================================");
        
        return originalJson.call(this, data);
    };
    
    // Add request timeout
    const timeout = setTimeout(() => {
        if (!res.headersSent) {
            console.log(`⏰ Request timeout for ${req.method} ${req.path} [${requestId}]`);
            res.status(408).json({ error: 'Request timeout' });
        }
    }, 30000); // 30 second timeout for all requests
    
    // Clear timeout when response is sent
    res.on('finish', () => clearTimeout(timeout));
    res.on('close', () => clearTimeout(timeout));
    
    console.log(`🔄 Request logging middleware completed, calling next() [${requestId}]`);
    next();
});

console.log("✅ Express app initialized with JSON middleware and request timeout");

// Add global error handlers to prevent crashes
process.on('unhandledRejection', (reason, promise) => {
    console.log('❌ Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
    console.log('❌ Uncaught Exception:', error);
    process.exit(1);
});

console.log("✅ Global error handlers configured");

// Add debugging middleware to track request flow
app.use((req, res, next) => {
    console.log(`🔍 Middleware chain: ${req.method} ${req.path} [${req.requestId}] - before routes`);
    next();
});


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

function requireAuth(f) {
    return async (req, res, next) => {
        console.log(`🔐 Authentication middleware called for endpoint: ${req.method} ${req.route?.path || req.path} [${req.requestId}]`);
        console.log(`🔐 About to start authentication process [${req.requestId}]`);
        
        // Set a timeout for the entire authentication process
        const authTimeout = setTimeout(() => {
            console.log(`⏰ Authentication timeout - request taking too long [${req.requestId}]`);
            if (!res.headersSent) {
                res.status(408).json({ error: 'Authentication timeout - request took too long' });
            }
        }, 5000); // 5 second timeout for entire auth process
        
        try {
            // Get Authorization header
            const authHeader = req.headers.authorization;
            console.log(`🔐 Authorization header check: ${authHeader ? 'Present' : 'Missing'} [${req.requestId}]`);
            
            if (!authHeader) {
                console.log("❌ Authentication failed: No Authorization header provided");
                clearTimeout(authTimeout);
                return res.status(401).json({ error: 'Authorization header is required' });
            }
            
            console.log(`🔐 About to verify Supabase auth [${req.requestId}]`);
            // Verify with Supabase
            const user = await verifySupabaseAuth(authHeader, req.requestId);
            console.log(`🔐 Supabase auth result: ${user ? 'Success' : 'Failed'} [${req.requestId}]`);
            
            if (!user) {
                console.log("❌ Authentication failed: Supabase verification failed");
                clearTimeout(authTimeout);
                return res.status(401).json({ error: 'Invalid or expired token' });
            }
            
            console.log(`🔐 About to get wallet details [${req.requestId}]`);
            // Get wallet details with timeout
            const walletDetails = await getWalletDetails(user.id, req.requestId);
            console.log(`🔐 Wallet details result: ${walletDetails ? 'Found' : 'Not found'} [${req.requestId}]`);
            
            // Log the authenticated user
            logAuthenticatedUser(user, walletDetails);
            
            // Add user info to request for use in the endpoint
            req.user = user;
            req.walletDetails = walletDetails;
            
            console.log("✅ Authentication successful, proceeding to endpoint handler");
            clearTimeout(authTimeout);
            return f(req, res, next);
            
        } catch (error) {
            console.log(`❌ Authentication error: ${error.message}`);
            clearTimeout(authTimeout);
            if (!res.headersSent) {
                return res.status(500).json({ error: 'Authentication failed due to server error' });
            }
        }
    };
}

async function runBackgroundTask(taskId, command, args = [], network = "mainnet", taskType = "script") {
    console.log(`🚀 Starting background task: ${taskId}`);
    console.log(`📋 Task details: command=${command}, args=${JSON.stringify(args)}, network=${network}, type=${taskType}`);
    const startTime = new Date();
    
    try {
        // Update network if different
        if (network !== flowWrapper.config.network) {
            console.log(`🔄 Updating network from ${flowWrapper.config.network} to ${network}`);
            flowWrapper.updateConfig({ network });
        }
        
        let result;
        
        // Parse command to determine operation type
        if (command.startsWith('script execute')) {
            const scriptPath = command.replace('script execute ', '').replace('scripts execute ', '');
            console.log(`📜 Executing script: ${scriptPath}`);
            result = await flowWrapper.executeScript(scriptPath, args);
        } else if (command.startsWith('transactions send')) {
            const transactionPath = command.replace('transactions send ', '').replace('transaction send ', '');
            console.log(`💸 Executing transaction: ${transactionPath}`);
            
            // For background tasks, we need to determine the roles based on the task type
            let proposer, authorizer, payer, authorizers;
            
            if (transactionPath.toLowerCase().includes('admin')) {
                // Admin operations use mainnet-agfarms for all roles
                proposer = 'mainnet-agfarms';
                authorizer = 'mainnet-agfarms';
                payer = 'mainnet-agfarms';
                console.log(`🔑 Admin transaction - using mainnet-agfarms for all roles`);
            } else {
                // User operations - hardcode proposer to mainnet-agfarms
                proposer = 'mainnet-agfarms'; // Hardcoded to mainnet-agfarms
                authorizers = ['mainnet-agfarms']; // Always include mainnet-agfarms
                payer = 'mainnet-agfarms';
                console.log(`👤 User transaction - using mainnet-agfarms as proposer/payer`);
                
                // Try to find user ID in args for additional authorizer
                for (let i = 0; i < args.length; i++) {
                    if (args[i] === '--authorizer' && i + 1 < args.length) {
                        authorizers.push(args[i + 1]);
                        console.log(`➕ Added user authorizer: ${args[i + 1]}`);
                        break;
                    }
                }
            }
            
            if (transactionPath.toLowerCase().includes('admin')) {
                result = await flowWrapper.sendTransaction(
                    transactionPath, 
                    args, 
                    { proposer, authorizer, payer }
                );
            } else {
                result = await flowWrapper.sendTransaction(
                    transactionPath, 
                    args, 
                    { proposer, authorizers, payer }
                );
            }
        } else {
            // For other commands, use the wrapper's internal command execution
            console.log(`⚡ Executing command: ${command}`);
            result = await flowWrapper.executeCommand(command, args);
        }
        
        // Convert FlowResult to legacy format for compatibility
        result = {
            success: result.success,
            stdout: result.rawOutput,
            stderr: result.errorMessage,
            returncode: result.success ? 0 : 1,
            command: result.command,
            execution_time: result.executionTime,
            network: result.network,
            transaction_id: result.transactionId
        };
        
        console.log(`✅ Background task completed: ${taskId}, success: ${result.success}`);
        if (result.transaction_id) {
            console.log(`📝 Transaction ID: ${result.transaction_id}`);
        }
    } catch (error) {
        console.log(`❌ Background task failed: ${taskId}, error: ${error.message}`);
        result = {
            success: false,
            stdout: '',
            stderr: error.message,
            returncode: -1,
            command: command,
            execution_time: 0.0,
            network: network
        };
    }
    
    const endTime = new Date();
    const duration = (endTime - startTime) / 1000;
    console.log(`⏱️  Task duration: ${duration.toFixed(3)}s`);
    
    // Store in memory
    backgroundTasks[taskId] = {
        status: 'completed',
        start_time: startTime.toISOString(),
        end_time: endTime.toISOString(),
        duration: duration,
        result: result
    };
    console.log(`💾 Task result stored in memory: ${taskId}`);
}

// Test endpoint without authentication
app.post('/test-endpoint', (req, res) => {
    console.log("🧪 TEST ENDPOINT CALLED");
    console.log(`🆔 Request ID: ${req.requestId}`);
    res.json({ message: 'Test endpoint working', requestId: req.requestId });
});

// Test send-bait endpoint without authentication
app.post('/test-send-bait', (req, res) => {
    console.log("🧪 TEST SEND BAIT ENDPOINT CALLED");
    console.log(`🆔 Request ID: ${req.requestId}`);
    console.log(`📦 Request Body: ${JSON.stringify(req.body)}`);
    res.json({ 
        message: 'Test send-bait endpoint working', 
        requestId: req.requestId,
        body: req.body
    });
});

// Simple test route to debug routing
app.post('/debug-route', (req, res) => {
    console.log("🐛 DEBUG ROUTE CALLED");
    console.log(`🆔 Request ID: ${req.requestId}`);
    res.json({ message: 'Debug route working', requestId: req.requestId });
});

// Test route with authentication to isolate the issue
app.post('/test-auth', requireAuth, (req, res) => {
    console.log("🔐 TEST AUTH ROUTE CALLED");
    console.log(`🆔 Request ID: ${req.requestId}`);
    res.json({ 
        message: 'Test auth route working', 
        requestId: req.requestId,
        user: req.user?.id 
    });
});

// Test route with simplified auth (no database query)
app.post('/test-auth-simple', async (req, res) => {
    console.log("🔐 TEST AUTH SIMPLE ROUTE CALLED");
    console.log(`🆔 Request ID: ${req.requestId}`);
    
    // Simple Supabase auth verification without database query
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'No valid auth header' });
    }
    
    try {
        const user = await verifySupabaseAuth(authHeader, req.requestId);
        if (!user) {
            return res.status(401).json({ error: 'Invalid token' });
        }
        
        res.json({ 
            message: 'Test auth simple route working', 
            requestId: req.requestId,
            user: user.id 
        });
    } catch (error) {
        res.status(401).json({ error: 'Invalid token' });
    }
});

// Test Supabase connection
app.get('/test-supabase', async (req, res) => {
    console.log("🗄️ TEST SUPABASE CONNECTION");
    console.log(`🆔 Request ID: ${req.requestId}`);
    
    try {
        if (!supabase) {
            return res.status(500).json({ error: 'Supabase client not configured' });
        }
        
        // Test a simple query with timeout
        const timeoutPromise = new Promise((_, reject) => {
            setTimeout(() => reject(new Error('Supabase test timeout')), 5000);
        });
        
        const testQuery = supabase
            .from('wallet')
            .select('count')
            .limit(1);
        
        const { data, error } = await Promise.race([testQuery, timeoutPromise]);
        
        if (error) {
            console.log(`❌ Supabase test error: ${error.message}`);
            return res.status(500).json({ 
                error: 'Supabase connection failed', 
                details: error.message 
            });
        }
        
        console.log(`✅ Supabase connection test successful`);
        res.json({ 
            message: 'Supabase connection working', 
            requestId: req.requestId,
            data: data 
        });
        
    } catch (error) {
        console.log(`❌ Supabase test error: ${error.message}`);
        res.status(500).json({ 
            error: 'Supabase test failed', 
            details: error.message 
        });
    }
});

// Routes
app.get('/', (req, res) => {
    res.json({
        message: 'Flow CLI HTTP Wrapper - UPDATED VERSION',
        version: '1.0.1',
        endpoints: {
            auth: {
                test_auth: 'GET /auth/test - Test JWT authentication',
                auth_status: 'GET /auth/status - Check authentication configuration'
            },
            scripts: {
                check_bait_balance: 'GET /scripts/check-bait-balance?address=<address>',
                check_contract_vaults: 'GET /scripts/check-contract-vaults',
                create_vault_and_mint: 'POST /scripts/create-vault-and-mint',
                sell_bait: 'POST /scripts/sell-bait',
                test_bait_coin_admin: 'POST /scripts/test-bait-coin-admin'
            },
            transactions: {
                admin_burn_bait: 'POST /transactions/admin-burn-bait (amount)',
                admin_mint_bait: 'POST /transactions/admin-mint-bait (to_address, amount)',
                admin_mint_fusd: 'POST /transactions/admin-mint-fusd (to_address, amount)',
                check_contract_usdf_balance: 'GET /transactions/check-contract-usdf-balance',
                create_all_vault: 'POST /transactions/create-all-vault (address)',
                create_usdf_vault: 'POST /transactions/create-usdf-vault (address)',
                reset_all_vaults: 'POST /transactions/reset-all-vaults',
                send_bait: 'POST /transactions/send-bait (to_address, amount)',
                send_fusd: 'POST /transactions/send-fusd (to_address, amount)',
                swap_bait_for_fusd: 'POST /transactions/swap-bait-for-fusd (amount)',
                swap_fusd_for_bait: 'POST /transactions/swap-fusd-for-bait (amount)',
                withdraw_contract_usdf: 'POST /transactions/withdraw-contract-usdf (amount)',
                deposit_flow: 'POST /transactions/deposit-flow (to_address, amount)'
            },
            background: {
                run_script: 'POST /background/run-script',
                run_transaction: 'POST /background/run-transaction',
                get_task_status: 'GET /background/task/<task_id>',
                list_tasks: 'GET /background/tasks'
            }
        }
    });
});

// Authentication test endpoints
app.get('/auth/status', (req, res) => {
    res.json({
        supabase_url_configured: !!SUPABASE_URL,
        supabase_anon_key_configured: !!SUPABASE_ANON_KEY,
        supabase_service_key_configured: !!SUPABASE_SERVICE_KEY,
        supabase_jwt_secret_configured: !!SUPABASE_JWT_SECRET,
        supabase_client_initialized: !!supabase,
        timestamp: new Date().toISOString()
    });
});

app.get('/auth/test', requireAuth, (req, res) => {
    res.json({
        message: 'Authentication successful!',
        user_id: req.user.id,
        email: req.user.email,
        wallet_address: getWalletAddress(req.walletDetails),
        wallet_type: req.walletDetails?.wallet_type || null,
        wallet_active: req.walletDetails?.is_active || null,
        timestamp: new Date().toISOString()
    });
});

// Script endpoints
app.get('/scripts/check-bait-balance', requireAuth, async (req, res) => {
    console.log("=== CHECK BAIT BALANCE ENDPOINT CALLED ===");
    console.log(`🆔 Request ID: ${req.requestId}`);
    console.log(`👤 User: ${req.user?.id}, Wallet: ${getWalletAddress(req.walletDetails)}`);
    let address = req.query.address;
    const network = req.query.network || 'mainnet';
    
    // Use authenticated user's wallet address as default if not specified
    if (!address) {
        address = getWalletAddress(req.walletDetails);
        if (address) {
            console.log(`✅ Using authenticated user's wallet address: ${address}`);
        } else {
            console.log("❌ No address provided and no wallet found for user");
            return res.status(400).json({ error: 'Address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    console.log(`🔍 Checking BAIT balance for address: ${address}, Network: ${network}`);
    
    // Use Flow wrapper for script execution
    const result = await flowWrapper.executeScript(
        'cadence/scripts/checkBaitBalance.cdc',
        [address]
    );
    
    console.log(`📊 Script execution result: success=${result.success}, execution_time=${result.executionTime}s`);
    if (result.transaction_id) {
        console.log(`📝 Transaction ID: ${result.transaction_id}`);
    }
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        data: result.data,
        execution_time: result.executionTime
    });
});

app.get('/scripts/check-contract-vaults', requireAuth, async (req, res) => {
    const network = req.query.network || 'mainnet';
    
    // Use Flow wrapper for script execution
    const result = await flowWrapper.executeScript(
        'cadence/scripts/checkContractVaults.cdc'
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        data: result.data,
        execution_time: result.executionTime
    });
});

app.post('/scripts/create-vault-and-mint', requireAuth, async (req, res) => {
    const data = req.body || {};
    const network = data.network || 'mainnet';
    
    // Use Flow wrapper for script execution
    const result = await flowWrapper.executeScript(
        'cadence/scripts/createVaultAndMint.cdc'
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        data: result.data,
        execution_time: result.executionTime
    });
});

app.post('/scripts/sell-bait', requireAuth, async (req, res) => {
    const data = req.body || {};
    const network = data.network || 'mainnet';
    
    // Use Flow wrapper for script execution
    const result = await flowWrapper.executeScript(
        'cadence/scripts/sellBait.cdc'
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        data: result.data,
        execution_time: result.executionTime
    });
});

app.post('/scripts/test-bait-coin-admin', requireAuth, async (req, res) => {
    const data = req.body || {};
    const network = data.network || 'mainnet';
    
    // Use Flow wrapper for script execution
    const result = await flowWrapper.executeScript(
        'cadence/scripts/testBaitCoinAdmin.cdc'
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        data: result.data,
        execution_time: result.executionTime
    });
});

// Transaction endpoints
app.post('/transactions/admin-burn-bait', requireAuth, async (req, res) => {
    const data = req.body || {};
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    if (!amount) {
        return res.status(400).json({ error: 'Amount parameter is required' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/adminBurnBait.cdc',
        [amount],
        {
            proposer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            authorizer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            payer: 'mainnet-agfarms' // Admin operation - use mainnet-agfarms
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/admin-mint-bait', requireAuth, async (req, res) => {
    console.log("=== ADMIN MINT BAIT ENDPOINT CALLED ===");
    console.log(`🆔 Request ID: ${req.requestId}`);
    console.log(`👤 User: ${req.user?.id}, Wallet: ${getWalletAddress(req.walletDetails)}`);
    const data = req.body || {};
    const amount = data.amount;
    let toAddress = data.to_address;
    const network = data.network || 'mainnet';
    
    console.log(`📋 Request data: amount=${amount}, to_address=${toAddress}, network=${network}`);
    
    if (!amount) {
        console.log("❌ Amount parameter missing");
        return res.status(400).json({ error: 'Amount parameter is required' });
    }
    
    // Use authenticated user's wallet address as default if not specified
    if (!toAddress) {
        toAddress = getWalletAddress(req.walletDetails);
        if (toAddress) {
            console.log(`✅ Using authenticated user's wallet address: ${toAddress}`);
        } else {
            console.log("❌ No to_address provided and no wallet found for user");
            return res.status(400).json({ error: 'to_address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    console.log(`💸 Admin minting ${amount} BAIT to address: ${toAddress}`);
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/adminMintBait.cdc',
        [toAddress, amount],
        {
            proposer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            authorizer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            payer: 'mainnet-agfarms' // Admin operation - use mainnet-agfarms
        }
    );
    
    console.log(`📊 Transaction execution result: success=${result.success}, execution_time=${result.executionTime}s`);
    if (result.transaction_id) {
        console.log(`📝 Transaction ID: ${result.transaction_id}`);
    }
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/admin-mint-fusd', requireAuth, async (req, res) => {
    const data = req.body || {};
    const amount = data.amount;
    let toAddress = data.to_address;
    const network = data.network || 'mainnet';
    
    if (!amount) {
        return res.status(400).json({ error: 'Amount parameter is required' });
    }
    
    // Use authenticated user's wallet address as default if not specified
    if (!toAddress) {
        toAddress = getWalletAddress(req.walletDetails);
        if (toAddress) {
            console.log(`Using authenticated user's wallet address: ${toAddress}`);
        } else {
            return res.status(400).json({ error: 'to_address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/adminMintFusd.cdc',
        [toAddress, amount],
        {
            proposer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            authorizer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            payer: 'mainnet-agfarms' // Admin operation - use mainnet-agfarms
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.get('/transactions/check-contract-usdf-balance', requireAuth, async (req, res) => {
    const network = req.query.network || 'mainnet';
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/checkContractUsdfBalance.cdc',
        [],
        {
            proposer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            authorizer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            payer: 'mainnet-agfarms' // Admin operation - use mainnet-agfarms
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/create-all-vault', requireAuth, async (req, res) => {
    const data = req.body || {};
    let address = data.address;
    const network = data.network || 'mainnet';
    
    // Use authenticated user's wallet address as default if not specified
    if (!address) {
        address = getWalletAddress(req.walletDetails);
        if (address) {
            console.log(`Using authenticated user's wallet address: ${address}`);
        } else {
            return res.status(400).json({ error: 'address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/createAllVault.cdc',
        [address],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/create-usdf-vault', requireAuth, async (req, res) => {
    const data = req.body || {};
    let address = data.address;
    const network = data.network || 'mainnet';
    
    // Use authenticated user's wallet address as default if not specified
    if (!address) {
        address = getWalletAddress(req.walletDetails);
        if (address) {
            console.log(`Using authenticated user's wallet address: ${address}`);
        } else {
            return res.status(400).json({ error: 'address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/createUsdfVault.cdc',
        [address],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/reset-all-vaults', requireAuth, async (req, res) => {
    const data = req.body || {};
    const network = data.network || 'mainnet';
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/resetAllVaults.cdc',
        [],
        {
            proposer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            authorizer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
            payer: 'mainnet-agfarms' // Admin operation - use mainnet-agfarms
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/send-bait', requireAuth, async (req, res) => {
    console.log("=== SEND BAIT ENDPOINT CALLED ===");
    console.log(`🆔 Request ID: ${req.requestId}`);
    console.log(`👤 User: ${req.user?.id}, Wallet: ${getWalletAddress(req.walletDetails)}`);
    const data = req.body || {};
    const toAddress = data.to_address;
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    console.log(`📋 Request data: amount=${amount}, to_address=${toAddress}, network=${network}`);
    
    if (!amount) {
        return res.status(400).json({ error: 'amount parameter is required' });
    }
    
    // Use authenticated user's wallet address as default if not specified
    if (!toAddress) {
        toAddress = getWalletAddress(req.walletDetails);
        if (toAddress) {
            console.log(`Using authenticated user's wallet address: ${toAddress}`);
        } else {
            return res.status(400).json({ error: 'to_address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/sendBait.cdc',
        [toAddress, amount],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/send-fusd', requireAuth, async (req, res) => {
    const data = req.body || {};
    const toAddress = data.to_address;
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    if (!amount) {
        return res.status(400).json({ error: 'amount parameter is required' });
    }
    
    // Use authenticated user's wallet address as default if not specified
    if (!toAddress) {
        toAddress = getWalletAddress(req.walletDetails);
        if (toAddress) {
            console.log(`Using authenticated user's wallet address: ${toAddress}`);
        } else {
            return res.status(400).json({ error: 'to_address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/sendFusd.cdc',
        [toAddress, amount],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/swap-bait-for-fusd', requireAuth, async (req, res) => {
    const data = req.body || {};
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    if (!amount) {
        return res.status(400).json({ error: 'Amount parameter is required' });
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/swapBaitForFusd.cdc',
        [amount],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/swap-fusd-for-bait', requireAuth, async (req, res) => {
    const data = req.body || {};
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    if (!amount) {
        return res.status(400).json({ error: 'Amount parameter is required' });
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/swapFusdForBait.cdc',
        [amount],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/withdraw-contract-usdf', requireAuth, async (req, res) => {
    const data = req.body || {};
    const amount = data.amount;
    const network = data.network || 'mainnet';
    
    if (!amount) {
        return res.status(400).json({ error: 'Amount parameter is required' });
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Use Flow wrapper for transaction execution
    const result = await flowWrapper.sendTransaction(
        'cadence/transactions/withdrawContractUsdf.cdc',
        [amount],
        {
            proposer: 'mainnet-agfarms', // Hardcoded to mainnet-agfarms
            authorizers: [userId], // Use user ID as additional authorizer (mainnet-agfarms is always included)
            payer: 'mainnet-agfarms' // Always use mainnet-agfarms as payer
        }
    );
    
    res.json({
        command: result.command,
        success: result.success,
        stdout: result.rawOutput,
        stderr: result.errorMessage,
        returncode: result.success ? 0 : 1,
        transaction_id: result.transactionId,
        execution_time: result.executionTime
    });
});

app.post('/transactions/deposit-flow', requireAuth, async (req, res) => {
    const data = req.body || {};
    let toAddress = data.to_address;
    const amount = data.amount || '0.25'; // Default 0.25 FLOW
    const network = data.network || 'mainnet';
    
    // Use authenticated user's wallet address as default if not specified
    if (!toAddress) {
        toAddress = getWalletAddress(req.walletDetails);
        if (toAddress) {
            console.log(`Using authenticated user's wallet address: ${toAddress}`);
        } else {
            return res.status(400).json({ error: 'to_address parameter is required and no wallet address found for authenticated user' });
        }
    }
    
    // Use Flow wrapper for transaction execution with inline code
    try {
        // Create a temporary transaction file for the inline code
        const inlineCode = `import FlowToken from 0x7e60df042a9c0868

transaction(recipient: Address, amount: UFix64) {
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault) 
            ?? panic("Could not borrow FlowToken vault")
        let tokens <- vault.withdraw(amount: amount)
        let recipient = getAccount(recipient)
        let receiver = recipient.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver) 
            ?? panic("Could not borrow FlowToken receiver")
        receiver.deposit(from: <-tokens)
    }
    execute {
        log("Transferred ".concat(amount.toString()).concat(" FLOW tokens").concat(" to ").concat(recipient.toString()))
    }
}`;
        
        // Write temporary transaction file
        const fs = require('fs');
        const path = require('path');
        const tempTxPath = path.join(flowWrapper.config.flowDir, 'temp_deposit_flow.cdc');
        fs.writeFileSync(tempTxPath, inlineCode);
        
        // Execute transaction
        const result = await flowWrapper.sendTransaction(
            'temp_deposit_flow.cdc',
            [`0x${toAddress}`, amount],
            {
                proposer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
                authorizer: 'mainnet-agfarms', // Admin operation - use mainnet-agfarms
                payer: 'mainnet-agfarms' // Admin operation - use mainnet-agfarms
            }
        );
        
        // Clean up temporary file
        try {
            fs.unlinkSync(tempTxPath);
        } catch (error) {
            // Ignore cleanup errors
        }
        
        res.json({
            command: result.command,
            success: result.success,
            stdout: result.rawOutput,
            stderr: result.errorMessage,
            returncode: result.success ? 0 : 1,
            transaction_id: result.transactionId,
            execution_time: result.executionTime
        });
        
    } catch (error) {
        res.json({
            command: 'deposit-flow transaction',
            success: false,
            stdout: '',
            stderr: error.message,
            returncode: -1
        });
    }
});

// Background task endpoints
app.post('/background/run-script', requireAuth, async (req, res) => {
    console.log("=== BACKGROUND RUN SCRIPT ENDPOINT CALLED ===");
    console.log(`🆔 Request ID: ${req.requestId}`);
    console.log(`👤 User: ${req.user?.id}, Wallet: ${getWalletAddress(req.walletDetails)}`);
    const data = req.body || {};
    const scriptName = data.script_name;
    const args = data.args || [];
    const network = data.network || 'mainnet';
    
    console.log(`📋 Script request: name=${scriptName}, args=${JSON.stringify(args)}, network=${network}`);
    
    if (!scriptName) {
        console.log("❌ Script name parameter missing");
        return res.status(400).json({ error: 'script_name parameter is required' });
    }
    
    const taskId = uuidv4();
    const startTime = new Date().toISOString();
    
    console.log(`🆔 Generated task ID: ${taskId}`);
    
    // Store in memory
    backgroundTasks[taskId] = {
        status: 'running',
        start_time: startTime,
        script_name: scriptName,
        args: args,
        network: network
    };
    
    console.log(`💾 Task stored in memory, total tasks: ${Object.keys(backgroundTasks).length}`);
    
    // Start background task
    setImmediate(() => {
        runBackgroundTask(taskId, `script execute cadence/scripts/${scriptName}`, args, network, 'script');
    });
    
    console.log(`✅ Background script task started: ${taskId}`);
    
    res.json({
        task_id: taskId,
        status: 'started',
        message: `Script ${scriptName} started in background`
    });
});

app.post('/background/run-transaction', requireAuth, async (req, res) => {
    const data = req.body || {};
    const transactionName = data.transaction_name;
    const args = data.args || [];
    const network = data.network || 'mainnet';
    
    if (!transactionName) {
        return res.status(400).json({ error: 'transaction_name parameter is required' });
    }
    
    // Get user ID for Flow account name
    const userId = req.user.id;
    if (!userId) {
        return res.status(400).json({ error: 'No user ID found in token' });
    }
    
    // Add proposer and authorizer to args if not already present
    if (!args.includes('--proposer')) {
        args.push('--proposer', userId);
    }
    if (!args.includes('--authorizer')) {
        args.push('--authorizer', userId);
    }
    
    const taskId = uuidv4();
    const startTime = new Date().toISOString();
    
    // Store in memory
    backgroundTasks[taskId] = {
        status: 'running',
        start_time: startTime,
        transaction_name: transactionName,
        args: args,
        network: network
    };
    
    // Start background task
    setImmediate(() => {
        runBackgroundTask(taskId, `transactions send cadence/transactions/${transactionName}`, args, network, 'transaction');
    });
    
    res.json({
        task_id: taskId,
        status: 'started',
        message: `Transaction ${transactionName} started in background`
    });
});

app.get('/background/task/:taskId', requireAuth, (req, res) => {
    const taskId = req.params.taskId;
    if (!(taskId in backgroundTasks)) {
        return res.status(404).json({ error: 'Task not found' });
    }
    
    res.json(backgroundTasks[taskId]);
});

app.get('/background/tasks', requireAuth, (req, res) => {
    res.json({
        tasks: backgroundTasks,
        count: Object.keys(backgroundTasks).length
    });
});

// Health check endpoint
app.get('/health', (req, res) => {
    const activeTasks = Object.values(backgroundTasks).filter(task => task.status === 'running').length;
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        active_tasks: activeTasks
    });
});

// Metrics endpoint
app.get('/metrics', requireAuth, (req, res) => {
    res.json({
        flow_metrics: flowWrapper.getMetrics(),
        timestamp: new Date().toISOString()
    });
});

// Reset metrics endpoint
app.post('/metrics/reset', requireAuth, (req, res) => {
    flowWrapper.resetMetrics();
    res.json({
        message: 'Metrics reset successfully',
        timestamp: new Date().toISOString()
    });
});

// Add a catch-all middleware to debug routing issues (after all routes)
app.use((req, res, next) => {
    console.log(`🔍 No route matched for: ${req.method} ${req.path} [${req.requestId}]`);
    res.status(404).json({ error: 'Route not found', path: req.path, method: req.method });
});

const PORT = process.env.PORT || 5000;
console.log("🌐 Starting HTTP server...");
app.listen(PORT, '0.0.0.0', () => {
    console.log("🎉 ==========================================");
    console.log("🎉 DerbyFish Flow API Server Started!");
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
    console.log("   GET  /auth/status - Authentication status");
    console.log("   GET  /auth/test - Test authentication");
    console.log("   GET  /scripts/* - Script endpoints");
    console.log("   POST /transactions/* - Transaction endpoints");
    console.log("   POST /background/* - Background task endpoints");
    console.log("   GET  /metrics - Flow metrics");
    console.log("🎉 ==========================================");
});

module.exports = app;
