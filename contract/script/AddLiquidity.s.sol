// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {IComputeToken} from "../src/ComputeToken.sol";

/// @title AddLiquidity
/// @notice CPT/USDC Pool に流動性を追加するスクリプト
contract AddLiquidity is Script {
    using PoolIdLibrary for PoolKey;

    int24 internal constant DEFAULT_TICK_SPACING = 60;

    struct AddLiquidityConfig {
        uint256 deployerPrivateKey;
        address deployer;
        string chainName;
        uint256 liquidityDeltaRaw;
        int256 liquidityDelta;
        int24 tickLower;
        int24 tickUpper;
        bytes32 liquiditySalt;
        uint256 mintCptAmount;
        address poolManager;
        address cpt;
        address usdc;
        address hook;
    }

    function run() external {
        AddLiquidityConfig memory cfg = _loadConfig();
        PoolKey memory key = _buildPoolKey(cfg.cpt, cfg.usdc, cfg.hook);
        bytes32 poolId = PoolId.unwrap(key.toId());
        (bool hasConfiguredPoolId, bytes32 configuredPoolId) =
            _tryReadPoolId(string.concat(vm.projectRoot(), "/deployed-addresses.json"), cfg.chainName, "poolId");
        if (hasConfiguredPoolId) {
            require(configuredPoolId == poolId, "AddLiquidity: poolId mismatch");
        }

        uint256 cptBalanceBefore = IERC20(cfg.cpt).balanceOf(cfg.deployer);
        uint256 usdcBalanceBefore = IERC20(cfg.usdc).balanceOf(cfg.deployer);
        console.log("Chain:", cfg.chainName);
        console.log("PoolId:", vm.toString(poolId));
        console.log("Deployer:", cfg.deployer);
        console.log("CPT balance before:", cptBalanceBefore);
        console.log("USDC balance before:", usdcBalanceBefore);
        console.log("Liquidity delta:", cfg.liquidityDeltaRaw);
        console.log("tickLower:", int256(cfg.tickLower));
        console.log("tickUpper:", int256(cfg.tickUpper));

        vm.startBroadcast(cfg.deployerPrivateKey);
        PoolModifyLiquidityTest modifyLiquidityRouter = new PoolModifyLiquidityTest(IPoolManager(cfg.poolManager));

        if (cfg.mintCptAmount > 0) {
            IComputeToken(cfg.cpt).mint(cfg.mintCptAmount);
        }

        IERC20(cfg.cpt).approve(address(modifyLiquidityRouter), type(uint256).max);
        IERC20(cfg.usdc).approve(address(modifyLiquidityRouter), type(uint256).max);

        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: cfg.tickLower,
                tickUpper: cfg.tickUpper,
                liquidityDelta: cfg.liquidityDelta,
                salt: cfg.liquiditySalt
            }),
            ""
        );
        vm.stopBroadcast();

        uint256 cptBalanceAfter = IERC20(cfg.cpt).balanceOf(cfg.deployer);
        uint256 usdcBalanceAfter = IERC20(cfg.usdc).balanceOf(cfg.deployer);
        console.log("CPT balance after:", cptBalanceAfter);
        console.log("USDC balance after:", usdcBalanceAfter);
        console.log("AddLiquidity: success");
    }

    function _loadConfig() private view returns (AddLiquidityConfig memory cfg) {
        cfg.deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        cfg.deployer = vm.addr(cfg.deployerPrivateKey);
        cfg.chainName = vm.envString("CHAIN_NAME");
        _validateSupportedChain(cfg.chainName);

        cfg.liquidityDeltaRaw = vm.envOr("LIQUIDITY_DELTA", uint256(1e18));
        require(cfg.liquidityDeltaRaw > 0, "AddLiquidity: LIQUIDITY_DELTA must be > 0");
        require(cfg.liquidityDeltaRaw <= uint256(type(int256).max), "AddLiquidity: LIQUIDITY_DELTA too large");
        cfg.liquidityDelta = int256(cfg.liquidityDeltaRaw);

        cfg.tickLower = int24(vm.envOr("LIQ_TICK_LOWER", int256(-120)));
        cfg.tickUpper = int24(vm.envOr("LIQ_TICK_UPPER", int256(120)));
        require(cfg.tickLower < cfg.tickUpper, "AddLiquidity: invalid tick range");
        require(cfg.tickLower % DEFAULT_TICK_SPACING == 0, "AddLiquidity: tickLower not aligned");
        require(cfg.tickUpper % DEFAULT_TICK_SPACING == 0, "AddLiquidity: tickUpper not aligned");

        cfg.liquiditySalt = bytes32(vm.envOr("LIQ_SALT", uint256(0)));
        cfg.mintCptAmount = vm.envOr("MINT_CPT_FOR_LP", uint256(0));

        string memory root = vm.projectRoot();
        string memory deployedPath = string.concat(root, "/deployed-addresses.json");
        cfg.poolManager = _readAddress(string.concat(root, "/uniswap-v4-addresses.json"), cfg.chainName);
        cfg.cpt = _readAddress(deployedPath, cfg.chainName, "cpt");
        cfg.usdc = _readAddress(string.concat(root, "/usdc-addresses.json"), cfg.chainName);
        cfg.hook = _readAddress(deployedPath, cfg.chainName, "hook");
    }

    function _buildPoolKey(address cpt, address usdc, address hook) private pure returns (PoolKey memory key) {
        (address token0, address token1) = cpt < usdc ? (cpt, usdc) : (usdc, cpt);
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

    function _tryReadPoolId(string memory path, string memory chainName, string memory field)
        private
        view
        returns (bool, bytes32)
    {
        string memory json = vm.readFile(path);
        try vm.parseJsonBytes32(json, string.concat(".", chainName, ".", field)) returns (bytes32 poolId) {
            return (true, poolId);
        } catch {
            return (false, bytes32(0));
        }
    }

    function _validateSupportedChain(string memory chainName) private pure {
        bytes32 chainHash = keccak256(bytes(chainName));
        bool isSupported = chainHash == keccak256(bytes("sepolia")) || chainHash == keccak256(bytes("base-sepolia"))
            || chainHash == keccak256(bytes("unichain-sepolia"));
        require(isSupported, "AddLiquidity: unsupported CHAIN_NAME");
    }
}
