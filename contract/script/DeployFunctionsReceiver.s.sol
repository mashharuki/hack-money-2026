// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {FunctionsReceiver} from "../src/functions/FunctionsReceiver.sol";

/// @title DeployFunctionsReceiver
/// @notice FunctionsReceiver をデプロイし、deployed-addresses.json に記録する
contract DeployFunctionsReceiver is Script {
    address internal constant DEFAULT_BASE_SEPOLIA_ROUTER = 0xf9B8fc078197181C841c296C876945aaa425B278;
    bytes32 internal constant DEFAULT_BASE_SEPOLIA_DON_ID = bytes32("fun-base-sepolia-1");
    uint32 internal constant DEFAULT_CALLBACK_GAS_LIMIT = 300_000;

    function run() external returns (FunctionsReceiver receiver) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory chainName = vm.envString("CHAIN_NAME");
        string memory deployedAddressesPath = string.concat(vm.projectRoot(), "/deployed-addresses.json");

        address oracle = _readRequiredAddress(deployedAddressesPath, string.concat(".", chainName, ".oracle"));
        address router = vm.envOr("FUNCTIONS_ROUTER", DEFAULT_BASE_SEPOLIA_ROUTER);
        uint64 subscriptionId = uint64(vm.envUint("FUNCTIONS_SUBSCRIPTION_ID"));
        uint32 callbackGasLimit = uint32(vm.envOr("FUNCTIONS_CALLBACK_GAS_LIMIT", uint256(DEFAULT_CALLBACK_GAS_LIMIT)));
        bytes32 donId = vm.envOr("FUNCTIONS_DON_ID", DEFAULT_BASE_SEPOLIA_DON_ID);

        vm.startBroadcast(deployerPrivateKey);
        receiver = new FunctionsReceiver(router, oracle, donId, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();

        console.log("FunctionsReceiver deployed at:", address(receiver));
        console.log("router:", router);
        console.log("oracle:", oracle);
        console.log("subscriptionId:", uint256(subscriptionId));
        console.log("callbackGasLimit:", uint256(callbackGasLimit));

        _writeFunctionsReceiverAddress(deployedAddressesPath, chainName, address(receiver));
    }

    function _writeFunctionsReceiverAddress(string memory path, string memory chainName, address receiver) private {
        string memory json = vm.serializeAddress(chainName, "functionsReceiver", receiver);
        json = _serializeAddressIfExists(json, path, chainName, "cpt");
        json = _serializeAddressIfExists(json, path, chainName, "oracle");
        json = _serializeAddressIfExists(json, path, chainName, "hook");
        json = _serializeAddressIfExists(json, path, chainName, "vault");
        json = _serializeBytes32IfExists(json, path, chainName, "poolId");

        vm.writeJson(json, path, string.concat(".", chainName));
    }

    function _serializeAddressIfExists(string memory json, string memory path, string memory chainName, string memory field)
        private
        returns (string memory)
    {
        (bool hasValue, address value) = _tryReadAddress(path, string.concat(".", chainName, ".", field));
        if (hasValue) {
            return vm.serializeAddress(chainName, field, value);
        }
        return json;
    }

    function _serializeBytes32IfExists(string memory json, string memory path, string memory chainName, string memory field)
        private
        returns (string memory)
    {
        (bool hasValue, bytes32 value) = _tryReadBytes32(path, string.concat(".", chainName, ".", field));
        if (hasValue) {
            return vm.serializeBytes32(chainName, field, value);
        }
        return json;
    }

    function _tryReadAddress(string memory path, string memory jsonPath) private view returns (bool, address) {
        string memory json = vm.readFile(path);
        try vm.parseJsonAddress(json, jsonPath) returns (address addr) {
            return (true, addr);
        } catch {
            return (false, address(0));
        }
    }

    function _readRequiredAddress(string memory path, string memory jsonPath) private view returns (address value) {
        (bool hasValue, address addr) = _tryReadAddress(path, jsonPath);
        require(hasValue, "oracle not found in deployed-addresses.json");
        return addr;
    }

    function _tryReadBytes32(string memory path, string memory jsonPath) private view returns (bool, bytes32) {
        string memory json = vm.readFile(path);
        try vm.parseJsonBytes32(json, jsonPath) returns (bytes32 value) {
            return (true, value);
        } catch {
            return (false, bytes32(0));
        }
    }
}
