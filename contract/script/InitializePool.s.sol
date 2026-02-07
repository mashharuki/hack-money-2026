// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

/// @title InitializePool
/// @notice CPT/USDC Pool を初期化するスクリプト
contract InitializePool is Script {
    uint160 internal constant DEFAULT_SQRT_PRICE_X96 = 79228162514264337593543950336; // 2^96 (price = 1)
    int24 internal constant DEFAULT_TICK_SPACING = 60;

    /**
     * メインロジック
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory chainName = vm.envString("CHAIN_NAME");
        // デプロイ済みのコントラクトの情報を読み取る
        address poolManager = _readAddress(string.concat(vm.projectRoot(), "/uniswap-v4-addresses.json"), chainName);
        address cptToken = _readAddress(string.concat(vm.projectRoot(), "/deployed-addresses.json"), chainName, "cpt");
        address usdcToken = _readAddress(string.concat(vm.projectRoot(), "/usdc-addresses.json"), chainName);
        address hook = _readAddress(string.concat(vm.projectRoot(), "/deployed-addresses.json"), chainName, "hook");

        vm.startBroadcast(deployerPrivateKey);
        // Poolを初期化
        initializePool(poolManager, cptToken, usdcToken, hook, DEFAULT_SQRT_PRICE_X96);
        vm.stopBroadcast();

        console.log("Pool initialized");
        console.log("PoolManager:", poolManager);
        console.log("CPT:", cptToken);
        console.log("USDC:", usdcToken);
        console.log("Hook:", hook);
    }

    /**
     * Poolを初期化
     * @param poolManager
     * @param cptToken
     * @param usdcToken
     * @param hook
     * @param sqrtPriceX96
     */
    function initializePool(address poolManager, address cptToken, address usdcToken, address hook, uint160 sqrtPriceX96)
        public
    {
        PoolKey memory key = _buildPoolKey(cptToken, usdcToken, hook);
        IPoolManager(poolManager).initialize(key, sqrtPriceX96);
    }

    /**
     * PoolKeyの算出
     * @param cptToken
     * @param usdcToken
     * @param hook
     */
    function _buildPoolKey(address cptToken, address usdcToken, address hook) private pure returns (PoolKey memory key) {
        (address token0, address token1) = cptToken < usdcToken ? (cptToken, usdcToken) : (usdcToken, cptToken);

        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: DEFAULT_TICK_SPACING,
            hooks: IHooks(hook)
        });
    }

    function _readAddress(string memory path, string memory chainName) private view returns (address) {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName));
    }

    function _readAddress(string memory path, string memory chainName, string memory field) private view returns (address) {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName, ".", field));
    }
}
