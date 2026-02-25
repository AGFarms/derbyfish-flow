"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
const path_1 = __importDefault(require("path"));
const fs = __importStar(require("fs"));
const CLI_PATH = path_1.default.join(process.cwd(), 'dist', 'cli.js');
const FLOW_DIR = path_1.default.join(__dirname, '../../..', 'flow');
const TEST_FLOW_DIR = path_1.default.join(__dirname, '../../..', 'tests', 'fixtures', 'flow');
function runCli(command, payload) {
    return new Promise((resolve) => {
        const encoded = Buffer.from(JSON.stringify(payload)).toString('base64');
        const proc = (0, child_process_1.spawn)('node', [CLI_PATH, command, `--payload=${encoded}`], {
            cwd: path_1.default.join(__dirname, '../../..'),
            env: { ...process.env }
        });
        let stdout = '';
        let stderr = '';
        proc.stdout.on('data', (d) => { stdout += d.toString(); });
        proc.stderr.on('data', (d) => { stderr += d.toString(); });
        proc.on('close', (code) => {
            resolve({ stdout, stderr, code: code ?? -1 });
        });
    });
}
describe('CLI', function () {
    const flowDir = fs.existsSync(path_1.default.join(TEST_FLOW_DIR, 'mainnet-agfarms.pkey')) ? TEST_FLOW_DIR : FLOW_DIR;
    it('returns error for unknown command', async function () {
        const result = await runCli('unknown-command', { network: 'mainnet', flowDir });
        const output = JSON.parse(result.stdout.trim());
        expect(output.success).toBe(false);
        expect(output.errorMessage).toContain('Unknown');
    });
    it('execute-script returns structured response', async function () {
        const scriptPath = 'cadence/scripts/checkBaitBalance.cdc';
        const result = await runCli('execute-script', {
            scriptPath,
            args: ['0xed2202de80195438'],
            network: 'mainnet',
            flowDir
        });
        const lines = result.stdout.trim().split('\n');
        const jsonLine = lines.find((l) => l.startsWith('{') && l.endsWith('}'));
        if (!jsonLine) {
            expect(result.code).toBe(0);
            return;
        }
        const output = JSON.parse(jsonLine);
        expect(output).toHaveProperty('success');
        expect(output).toHaveProperty('data');
        expect(output).toHaveProperty('errorMessage');
    });
});
