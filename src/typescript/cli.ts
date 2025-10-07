#!/usr/bin/env node
import path from 'path';
import { FlowNetwork } from './types';
import { createFlowWrapper } from './flowWrapper';

function print(data: any) {
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

    const network: FlowNetwork | string = payload.network || FlowNetwork.MAINNET;
    const flowDir = payload.flowDir || path.join(process.cwd(), 'flow');
    const wrapper = createFlowWrapper(network as any, { flowDir });

    console.log(`Network: ${network}`);
    console.log(`Flow Directory: ${flowDir}`);

    if (command === 'execute-script') {
      const scriptPath = payload.scriptPath;
      const scriptArgs = payload.args || [];
      console.log(`Executing script: ${scriptPath} with args: ${JSON.stringify(scriptArgs)}`);
      const result = await wrapper.executeScript(scriptPath, scriptArgs);
      console.log(`Script execution result: ${JSON.stringify(result, null, 2)}`);
      print({ success: result.success, data: result.data, errorMessage: result.errorMessage });
      return;
    }

    if (command === 'send-transaction') {
      const transactionPath = payload.transactionPath;
      const txArgs = payload.args || [];
      const roles = payload.roles || {};
      console.log(`Sending transaction: ${transactionPath} with args: ${JSON.stringify(txArgs)} and roles: ${JSON.stringify(roles)}`);
      const result: any = await wrapper.sendTransaction(transactionPath, txArgs, roles);
      console.log(`Transaction execution result: ${JSON.stringify(result, null, 2)}`);
      print({ 
        success: result.success, 
        transactionId: result.transactionId, 
        data: result.data, 
        errorMessage: result.errorMessage 
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
  } catch (error: any) {
    console.error(`CLI Error: ${error?.message || String(error)}`);
    console.error(`Error Stack: ${error?.stack}`);
    print({ success: false, errorMessage: error?.message || String(error) });
    process.exitCode = 1;
  }
}

main();


