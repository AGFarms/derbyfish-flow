"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = __importDefault(require("path"));
const flowWrapper_1 = require("../flowWrapper");
const types_1 = require("../types");
jest.mock('@onflow/fcl', () => ({
    config: () => ({
        put: jest.fn(),
        get: jest.fn()
    }),
    query: jest.fn(),
    mutate: jest.fn(),
    tx: jest.fn(),
    send: jest.fn(),
    decode: jest.fn(),
    arg: jest.fn((val) => val),
    sansPrefix: jest.fn((addr) => addr.replace(/^0x/, '')),
    withPrefix: jest.fn((addr) => addr.startsWith('0x') ? addr : `0x${addr}`),
    getAccount: jest.fn(),
    getBlock: jest.fn(),
    atBlockId: jest.fn(),
    t: {
        Address: 'Address',
        UFix64: 'UFix64',
        String: 'String'
    }
}));
jest.mock('../supabase', () => ({
    transactionLogger: {
        createTransaction: jest.fn().mockResolvedValue({ id: 'tx-123' }),
        updateTransaction: jest.fn().mockResolvedValue(null),
        updateTransactionByFlowId: jest.fn().mockResolvedValue(null)
    }
}));
const TEST_FLOW_DIR = path_1.default.join(__dirname, '../../..', 'tests', 'fixtures', 'flow');
describe('FlowResult', function () {
    it('creates result with defaults', function () {
        const result = new flowWrapper_1.FlowResult();
        expect(result.success).toBe(false);
        expect(result.data).toBeNull();
        expect(result.errorMessage).toBe('');
        expect(result.transactionId).toBeNull();
    });
    it('creates result with options', function () {
        const result = new flowWrapper_1.FlowResult({
            success: true,
            data: { balance: '1.5' },
            transactionId: 'abc123',
            executionTime: 100
        });
        expect(result.success).toBe(true);
        expect(result.data).toEqual({ balance: '1.5' });
        expect(result.transactionId).toBe('abc123');
        expect(result.executionTime).toBe(100);
    });
    it('toDict returns serializable object', function () {
        const result = new flowWrapper_1.FlowResult({
            success: true,
            data: { balance: '1.5' },
            transactionId: 'tx-1',
            executionTime: 50,
            blockHeight: 12345,
            blockTimestamp: '2024-01-01T00:00:00Z',
            gasUsed: 1000
        });
        const dict = result.toDict();
        expect(dict).toEqual({
            success: true,
            data: { balance: '1.5' },
            errorMessage: '',
            transactionId: 'tx-1',
            executionTime: 50,
            blockHeight: 12345,
            blockTimestamp: '2024-01-01T00:00:00Z',
            gasUsed: 1000
        });
    });
});
describe('FlowConfig', function () {
    it('creates config with defaults', function () {
        const config = new flowWrapper_1.FlowConfig();
        expect(config.network).toBe(types_1.FlowNetwork.MAINNET);
        expect(config.flowDir).toContain('flow');
    });
    it('creates config with options', function () {
        const config = new flowWrapper_1.FlowConfig({
            network: types_1.FlowNetwork.TESTNET,
            flowDir: '/custom/flow'
        });
        expect(config.network).toBe(types_1.FlowNetwork.TESTNET);
        expect(config.flowDir).toBe('/custom/flow');
    });
});
describe('FlowWrapper - getAccessNode', function () {
    let wrapper;
    beforeAll(function () {
        wrapper = (0, flowWrapper_1.createFlowWrapper)(types_1.FlowNetwork.MAINNET, { flowDir: TEST_FLOW_DIR });
    });
    it('returns mainnet access node for MAINNET', function () {
        expect(wrapper.getAccessNode(types_1.FlowNetwork.MAINNET)).toBe('https://rest-mainnet.onflow.org');
    });
    it('returns testnet access node for TESTNET', function () {
        expect(wrapper.getAccessNode(types_1.FlowNetwork.TESTNET)).toBe('https://rest-testnet.onflow.org');
    });
    it('returns emulator for EMULATOR', function () {
        expect(wrapper.getAccessNode(types_1.FlowNetwork.EMULATOR)).toBe('http://127.0.0.1:8888');
    });
});
describe('FlowWrapper - executeScript', function () {
    const fcl = require('@onflow/fcl');
    let wrapper;
    beforeAll(function () {
        wrapper = (0, flowWrapper_1.createFlowWrapper)(types_1.FlowNetwork.MAINNET, { flowDir: TEST_FLOW_DIR });
    });
    beforeEach(function () {
        jest.clearAllMocks();
    });
    it('executes script and returns success', async function () {
        fcl.query = jest.fn().mockResolvedValue('1.5');
        const scriptPath = 'cadence/scripts/checkBaitBalance.cdc';
        const result = await wrapper.executeScript(scriptPath, ['0xed2202de80195438']);
        expect(result.success).toBe(true);
        expect(result.data).toBe('1.5');
    });
    it('handles script execution failure', async function () {
        fcl.query = jest.fn().mockRejectedValue(new Error('Script failed'));
        const scriptPath = 'cadence/scripts/checkBaitBalance.cdc';
        const result = await wrapper.executeScript(scriptPath, []);
        expect(result.success).toBe(false);
        expect(result.errorMessage).toBe('Script failed');
    });
});
describe('FlowWrapper - getAccount', function () {
    const fcl = require('@onflow/fcl');
    let wrapper;
    beforeAll(function () {
        wrapper = (0, flowWrapper_1.createFlowWrapper)(types_1.FlowNetwork.MAINNET, { flowDir: TEST_FLOW_DIR });
    });
    beforeEach(function () {
        jest.clearAllMocks();
    });
    it('returns account data on success', async function () {
        const mockAccount = { address: '0xed2202de80195438', keys: [] };
        fcl.send = jest.fn().mockResolvedValue({});
        fcl.decode = jest.fn().mockResolvedValue(mockAccount);
        const result = await wrapper.getAccount('0xed2202de80195438');
        expect(result.success).toBe(true);
        expect(result.data).toEqual(mockAccount);
    });
    it('returns error on failure', async function () {
        fcl.send = jest.fn().mockRejectedValue(new Error('Account not found'));
        const result = await wrapper.getAccount('0xinvalid');
        expect(result.success).toBe(false);
        expect(result.errorMessage).toBe('Account not found');
    });
});
describe('FlowWrapper - getTransaction', function () {
    const fcl = require('@onflow/fcl');
    let wrapper;
    beforeAll(function () {
        wrapper = (0, flowWrapper_1.createFlowWrapper)(types_1.FlowNetwork.MAINNET, { flowDir: TEST_FLOW_DIR });
    });
    beforeEach(function () {
        jest.clearAllMocks();
    });
    it('returns transaction data on success', async function () {
        const mockTx = { id: 'tx-123', status: 4 };
        fcl.tx = jest.fn().mockReturnValue({
            onceSealed: jest.fn().mockResolvedValue(mockTx)
        });
        const result = await wrapper.getTransaction('tx-123');
        expect(result.success).toBe(true);
        expect(result.data).toEqual(mockTx);
        expect(result.transactionId).toBe('tx-123');
    });
    it('returns error on failure', async function () {
        fcl.tx = jest.fn().mockReturnValue({
            onceSealed: jest.fn().mockRejectedValue(new Error('Transaction not found'))
        });
        const result = await wrapper.getTransaction('tx-nonexistent');
        expect(result.success).toBe(false);
        expect(result.errorMessage).toBe('Transaction not found');
    });
});
