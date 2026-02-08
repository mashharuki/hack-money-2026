// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {IComputeToken} from "../src/ComputeToken.sol";

/// @title SwapPool
/// @notice Execute a swap on a CPT/USDC pool to move the price
/// @dev Uses proper sqrtPriceLimitX96 to allow meaningful price movement
contract SwapPool is Script {
    using PoolIdLibrary for PoolKey;

    int24 internal constant DEFAULT_TICK_SPACING = 60;

    struct SwapConfig {
        uint256 deployerPrivateKey;
        string chainName;
        address poolManager;
        address cpt;
        address usdc;
        address hook;
        bool zeroForOne;
        uint256 swapAmount;
    }

    function run() external {
        SwapConfig memory cfg = _loadConfig();
        PoolKey memory key = _buildPoolKey(cfg.cpt, cfg.usdc, cfg.hook);

        _logBefore(cfg, key);

        uint160 sqrtPriceLimitX96 = cfg.zeroForOne
            ? TickMath.MIN_SQRT_PRICE + 1
            : TickMath.MAX_SQRT_PRICE - 1;

        vm.startBroadcast(cfg.deployerPrivateKey);
        PoolSwapTest swapRouter = new PoolSwapTest(IPoolManager(cfg.poolManager));
        IComputeToken(cfg.cpt).mint(cfg.swapAmount * 10);
        IERC20(cfg.cpt).approve(address(swapRouter), type(uint256).max);
        IERC20(cfg.usdc).approve(address(swapRouter), type(uint256).max);

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: cfg.zeroForOne,
                amountSpecified: -int256(cfg.swapAmount),
                sqrtPriceLimitX96: sqrtPriceLimitX96
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.stopBroadcast();

        _logAfter(cfg, key);
    }

    function _loadConfig() internal view returns (SwapConfig memory cfg) {
        cfg.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        cfg.chainName = vm.envString("CHAIN_NAME");
        string memory root = vm.projectRoot();
        string memory deployedPath = string.concat(root, "/deployed-addresses.json");
        cfg.poolManager = _readAddress(string.concat(root, "/uniswap-v4-addresses.json"), cfg.chainName);
        cfg.cpt = _readAddress(deployedPath, cfg.chainName, "cpt");
        cfg.usdc = _readAddress(string.concat(root, "/usdc-addresses.json"), cfg.chainName);
        cfg.hook = _readAddress(deployedPath, cfg.chainName, "hook");
        cfg.zeroForOne = vm.envOr("SWAP_ZERO_FOR_ONE", true);
        cfg.swapAmount = vm.envOr("SWAP_AMOUNT", uint256(100000));
    }

    function _logBefore(SwapConfig memory cfg, PoolKey memory key) internal view {
        (uint160 sqrtPrice, int24 tick,,) = StateLibrary.getSlot0(IPoolManager(cfg.poolManager), key.toId());
        uint128 liq = StateLibrary.getLiquidity(IPoolManager(cfg.poolManager), key.toId());
        console.log("Chain:", cfg.chainName);
        console.log("zeroForOne:", cfg.zeroForOne);
        console.log("swapAmount:", cfg.swapAmount);
        console.log("Before sqrtPriceX96:", sqrtPrice);
        console.log("Before tick:", int256(tick));
        console.log("Liquidity:", uint256(liq));
        require(liq > 0, "SwapPool: pool has no liquidity");
    }

    function _logAfter(SwapConfig memory cfg, PoolKey memory key) internal view {
        (uint160 sqrtPrice, int24 tick,,) = StateLibrary.getSlot0(IPoolManager(cfg.poolManager), key.toId());
        console.log("After sqrtPriceX96:", sqrtPrice);
        console.log("After tick:", int256(tick));
        console.log("SwapPool: success");
    }

    function _buildPoolKey(address cpt, address usdc, address hook) internal pure returns (PoolKey memory key) {
        (address token0, address token1) = cpt < usdc ? (cpt, usdc) : (usdc, cpt);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: DEFAULT_TICK_SPACING,
            hooks: IHooks(hook)
        });
    }

    function _readAddress(string memory path, string memory chainName) internal view returns (address) {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName));
    }

    function _readAddress(string memory path, string memory chainName, string memory field)
        internal
        view
        returns (address)
    {
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", chainName, ".", field));
    }

    function _readPoolId(string memory path, string memory chainName, string memory field)
        internal
        view
        returns (bytes32)
    {
        string memory json = vm.readFile(path);
        return vm.parseJsonBytes32(json, string.concat(".", chainName, ".", field));
    }
}
