// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IComputeToken} from "../src/ComputeToken.sol";

/// @title MintCpt
/// @notice デプロイ済み CPT を mint するスクリプト
contract MintCpt is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        string memory chainName = vm.envString("CHAIN_NAME");
        uint256 mintAmount = vm.envUint("MINT_CPT_AMOUNT");
        require(mintAmount > 0, "MintCpt: MINT_CPT_AMOUNT must be > 0");

        address mintTo = vm.envOr("MINT_CPT_TO", deployer);
        require(mintTo != address(0), "MintCpt: invalid recipient");

        string memory deployedPath = string.concat(vm.projectRoot(), "/deployed-addresses.json");
        address cpt = _readAddress(deployedPath, chainName, "cpt");

        vm.startBroadcast(deployerPrivateKey);
        IComputeToken(cpt).mint(mintAmount);
        vm.stopBroadcast();

        if (mintTo != deployer) {
            vm.startBroadcast(deployerPrivateKey);
            bool ok = IComputeToken(cpt).transfer(mintTo, mintAmount);
            require(ok, "MintCpt: transfer failed");
            vm.stopBroadcast();
        }

        console.log("MintCpt: success");
        console.log("Chain:", chainName);
        console.log("CPT:", cpt);
        console.log("Minter:", deployer);
        console.log("Recipient:", mintTo);
        console.log("Amount:", mintAmount);
    }

    function _readAddress(string memory path, string memory chainName, string memory field) private view returns (address) {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName, ".", field));
    }
}
