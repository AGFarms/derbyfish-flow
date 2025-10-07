"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FlowNetwork = exports.FlowOperationType = void 0;
var FlowOperationType;
(function (FlowOperationType) {
    FlowOperationType["SCRIPT"] = "script";
    FlowOperationType["TRANSACTION"] = "transaction";
    FlowOperationType["ACCOUNT"] = "account";
    FlowOperationType["BLOCK"] = "block";
})(FlowOperationType || (exports.FlowOperationType = FlowOperationType = {}));
var FlowNetwork;
(function (FlowNetwork) {
    FlowNetwork["MAINNET"] = "mainnet";
    FlowNetwork["TESTNET"] = "testnet";
    FlowNetwork["EMULATOR"] = "emulator";
})(FlowNetwork || (exports.FlowNetwork = FlowNetwork = {}));
