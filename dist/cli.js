#!/usr/bin/env node
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = __importDefault(require("path"));
const types_1 = require("./types");
const flowWrapper_1 = require("./flowWrapper");
function print(data) {
    process.stdout.write(JSON.stringify(data));
}
async function main() {
    try {
        const args = process.argv.slice(2);
        const command = args[0];
        const payloadArg = args.find(a => a.startsWith('--payload='));
        const payload = payloadArg ? JSON.parse(Buffer.from(payloadArg.split('=')[1], 'base64').toString('utf8')) : {};
        console.log('=== TYPESCRIPT CLI EXECUTION ===');
        console.log(`Command: ${command}`);
        console.log(`Payload: ${JSON.stringify(payload, null, 2)}`);
        console.log(`Process Arguments: ${JSON.stringify(args, null, 2)}`);
        const network = payload.network || types_1.FlowNetwork.MAINNET;
        const flowDir = payload.flowDir || path_1.default.join(process.cwd(), 'flow');
        const wrapper = (0, flowWrapper_1.createFlowWrapper)(network, { flowDir });
        console.log(`Network: ${network}`);
        console.log(`Flow Directory: ${flowDir}`);
        if (command === 'execute-script') {
            const scriptPath = payload.scriptPath;
            const scriptArgs = payload.args || [];
            const proposerWalletId = payload.proposerWalletId;
            console.log(`Executing script: ${scriptPath} with args: ${JSON.stringify(scriptArgs)}`);
            const result = await wrapper.executeScript(scriptPath, scriptArgs, proposerWalletId);
            console.log(`Script execution result: ${JSON.stringify(result, null, 2)}`);
            print({ success: result.success, data: result.data, errorMessage: result.errorMessage, transactionId: result.transactionId });
            return;
        }
        if (command === 'send-transaction') {
            const transactionPath = payload.transactionPath;
            const txArgs = payload.args || [];
            const roles = payload.roles || {};
            const privateKeys = payload.privateKeys || {};
            const proposerWalletId = payload.proposerWalletId;
            const payerWalletId = payload.payerWalletId;
            const authorizerWalletIds = payload.authorizerWalletIds;
            console.log(`Sending transaction: ${transactionPath} with args: ${JSON.stringify(txArgs)} and roles: ${JSON.stringify(roles)}`);
            if (Object.keys(privateKeys).length > 0) {
                console.log(`Using private keys for accounts: ${Object.keys(privateKeys).join(', ')}`);
            }
            const result = await wrapper.sendTransaction(transactionPath, txArgs, roles, privateKeys, proposerWalletId, payerWalletId, authorizerWalletIds);
            console.log(`Transaction execution result: ${JSON.stringify(result, null, 2)}`);
            print({
                success: result.success,
                transactionId: result.transactionId,
                data: result.data,
                errorMessage: result.errorMessage,
                dbTransactionId: result.dbTransactionId
            });
            return;
        }
        if (command === 'get-transaction') {
            const transactionId = payload.transactionId;
            console.log(`Getting transaction: ${transactionId}`);
            const result = await wrapper.getTransaction(transactionId);
            console.log(`Get transaction result: ${JSON.stringify(result, null, 2)}`);
            print(result.toDict ? result.toDict() : result);
            return;
        }
        if (command === 'get-account') {
            const address = payload.address;
            console.log(`Getting account: ${address}`);
            const result = await wrapper.getAccount(address);
            console.log(`Get account result: ${JSON.stringify(result, null, 2)}`);
            print(result.toDict ? result.toDict() : result);
            return;
        }
        console.log(`Unknown command: ${command}`);
        print({ success: false, errorMessage: 'Unknown command' });
    }
    catch (error) {
        console.error(`CLI Error: ${error?.message || String(error)}`);
        console.error(`Error Stack: ${error?.stack}`);
        print({ success: false, errorMessage: error?.message || String(error) });
        process.exitCode = 1;
    }
}
main();
