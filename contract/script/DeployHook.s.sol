// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IMockOracle} from "../src/MockOracle.sol";
import {UtilizationHook} from "../src/hooks/UtilizationHook.sol";
import {HookMiner} from "../src/lib/HookMiner.sol";

/// @title DeployHook
/// @notice UtilizationHook を CREATE2 + HookMiner でデプロイするスクリプト
contract DeployHook is Script {
    /// @notice EIP-2470 Deterministic Deployment Proxy
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /**
     * メイン関数
     */
    function run() external returns (UtilizationHook hook) {
        // 環境変数から読み取る
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory chainName = vm.envString("CHAIN_NAME");
        address poolManager =
            _readPoolManagerAddress(string.concat(vm.projectRoot(), "/uniswap-v4-addresses.json"), chainName);
        address mockOracle = _readOracleAddress(string.concat(vm.projectRoot(), "/deployed-addresses.json"), chainName);

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory creationCode = type(UtilizationHook).creationCode;
        bytes memory constructorArgs = abi.encode(IPoolManager(poolManager), IMockOracle(mockOracle));

        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, creationCode, constructorArgs);

        console.log("Deployer EOA:", vm.addr(deployerPrivateKey));
        console.log("PoolManager:", poolManager);
        console.log("MockOracle:", mockOracle);
        console.log("Flags:", uint256(flags));
        console.log("Mined Hook Address:", expectedHookAddress);
        console.log("Salt:", vm.toString(salt));

        vm.startBroadcast(deployerPrivateKey);
        (bool ok,) = CREATE2_DEPLOYER.call(abi.encodePacked(salt, abi.encodePacked(creationCode, constructorArgs)));
        require(ok, "DeployHook: CREATE2 deployment failed");
        vm.stopBroadcast();

        address deployedHookAddress = HookMiner.computeAddress(CREATE2_DEPLOYER, salt, creationCode, constructorArgs);
        require(deployedHookAddress == expectedHookAddress, "DeployHook: address mismatch");
        require(deployedHookAddress.code.length > 0, "DeployHook: deployed code missing");

        hook = UtilizationHook(deployedHookAddress);
        console.log("Hook deployed at:", deployedHookAddress);
    }

    function _readPoolManagerAddress(string memory path, string memory chainName) private view returns (address) {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName));
    }

    function _readOracleAddress(string memory path, string memory chainName) private view returns (address) {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName, ".oracle"));
    }
}
