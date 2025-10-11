#!/usr/bin/env node
import path from 'path';
import { FlowNetwork } from './types';
import { createFlowWrapper } from './flowWrapper';

function print(data: any) {
  process.stdout.write(JSON.stringify(data));
}

async function main() {
  try {
    console.error('=== CLI DEBUG START ===');
    const args = process.argv.slice(2);
    const command = args[0];
    const payloadArg = args.find(a => a.startsWith('--payload='));
    const payload = payloadArg ? JSON.parse(Buffer.from(payloadArg.split('=')[1], 'base64').toString('utf8')) : {};

    console.error('CLI Args:', args);
    console.error('CLI Command:', command);
    console.error('CLI Payload:', JSON.stringify(payload, null, 2));

    const network: FlowNetwork | string = payload.network || FlowNetwork.MAINNET;
    const flowDir = payload.flowDir || path.join(process.cwd(), 'flow');
    console.error('CLI Network:', network);
    console.error('CLI FlowDir:', flowDir);
    
    const wrapper = createFlowWrapper(network as any, { flowDir });
    console.error('CLI Wrapper created successfully');

    if (command === 'execute-script') {
      const scriptPath = payload.scriptPath;
      const scriptArgs = payload.args || [];
      const proposerWalletId = payload.proposerWalletId;
      const result = await wrapper.executeScript(scriptPath, scriptArgs, proposerWalletId);
      print({ success: result.success, data: result.data, errorMessage: result.errorMessage, transactionId: result.transactionId });
      return;
    }

    if (command === 'send-transaction') {
      console.error('=== SEND TRANSACTION COMMAND ===');
      const transactionPath = payload.transactionPath;
      const txArgs = payload.args || [];
      const roles = payload.roles || {};
      const privateKeys = payload.privateKeys || {};
      const proposerWalletId = payload.proposerWalletId;
      const payerWalletId = payload.payerWalletId;
      const authorizerWalletIds = payload.authorizerWalletIds;
      
      console.error('Transaction Path:', transactionPath);
      console.error('Transaction Args:', txArgs);
      console.error('Roles:', roles);
      console.error('Private Keys:', Object.keys(privateKeys));
      console.error('Proposer Wallet ID:', proposerWalletId);
      console.error('Payer Wallet ID:', payerWalletId);
      console.error('Authorizer Wallet IDs:', authorizerWalletIds);
      
      console.error('Calling wrapper.sendTransaction...');
      const result: any = await wrapper.sendTransaction(transactionPath, txArgs, roles, privateKeys, proposerWalletId, payerWalletId, authorizerWalletIds);
      console.error('Send transaction result:', result);
      
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
      const result = await wrapper.getTransaction(transactionId);
      print(result.toDict ? result.toDict() : result);
      return;
    }

    if (command === 'get-account') {
      const address = payload.address;
      const result = await wrapper.getAccount(address);
      print(result.toDict ? result.toDict() : result);
      return;
    }

    print({ success: false, errorMessage: 'Unknown command' });
  } catch (error: any) {
    console.error(`❌ CLI Error: ${error?.message || String(error)}`);
    print({ success: false, errorMessage: error?.message || String(error) });
    process.exitCode = 1;
  }
}

main();


