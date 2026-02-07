// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IMockOracle} from "../src/MockOracle.sol";

/// @title AuthorizeFunctionsReceiver
/// @notice Oracle の allowlist に FunctionsReceiver を登録/解除する運用スクリプト
contract AuthorizeFunctionsReceiver is Script {
    /**
     * @notice スクリプト実行エントリーポイント
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory chainName = vm.envString("CHAIN_NAME");
        string memory deployedAddressesPath = string.concat(vm.projectRoot(), "/deployed-addresses.json");
        // deployed-addresses.json から Oracle と FunctionsReceiver のアドレスを取得
        address oracle = _readRequiredAddress(deployedAddressesPath, string.concat(".", chainName, ".oracle"));
        address receiver = _readRequiredAddress(deployedAddressesPath, string.concat(".", chainName, ".functionsReceiver"));
        bool allowed = vm.envOr("ALLOWED", true);

        vm.startBroadcast(deployerPrivateKey);
        // Oracle の allowlist に FunctionsReceiver を登録/解除
        IMockOracle(oracle).setAuthorizedUpdater(receiver, allowed);
        vm.stopBroadcast();

        console.log("Oracle updater authorization updated");
        console.log("oracle:", oracle);
        console.log("receiver:", receiver);
        console.log("allowed:", allowed);
    }

    function _readRequiredAddress(string memory path, string memory jsonPath) private view returns (address value) {
        string memory json = vm.readFile(path);
        try vm.parseJsonAddress(json, jsonPath) returns (address addr) {
            return addr;
        } catch {
            revert("required address not found in deployed-addresses.json");
        }
    }
}
