// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {UtilizationHook} from "../src/hooks/UtilizationHook.sol";
import {IMockOracle, MockOracle} from "../src/MockOracle.sol";

/// @title UtilizationHookTest
/// @notice Task 2.1: UtilizationHook コントラクトスケルトンのテスト
contract UtilizationHookTest is Test {
    UtilizationHook public hook;
    MockOracle public oracle;
    IPoolManager public poolManager;

    function setUp() public {
        // PoolManager をデプロイ
        poolManager = new PoolManager(address(this));

        // MockOracle をデプロイ
        oracle = new MockOracle();

        // UtilizationHook をデプロイ（テスト用にアドレス制約なし）
        // 本番では CREATE2 + HookMiner が必要だが、ここではスケルトン検証のみ
        hook = new UtilizationHook(poolManager, IMockOracle(address(oracle)));
    }

    /// @notice oracle() が正しいアドレスを返すことを検証
    function test_oracle_returnsCorrectAddress() public view {
        assertEq(address(hook.oracle()), address(oracle));
    }

    /// @notice poolManager が正しく設定されていることを検証
    function test_poolManager_isSetCorrectly() public view {
        assertEq(address(hook.poolManager()), address(poolManager));
    }

    /// @notice LOW_FEE が 500 (0.05%) であることを検証
    function test_LOW_FEE_is500() public view {
        assertEq(hook.LOW_FEE(), 500);
    }

    /// @notice DEFAULT_FEE が 3000 (0.3%) であることを検証
    function test_DEFAULT_FEE_is3000() public view {
        assertEq(hook.DEFAULT_FEE(), 3000);
    }

    /// @notice HIGH_FEE が 10000 (1.0%) であることを検証
    function test_HIGH_FEE_is10000() public view {
        assertEq(hook.HIGH_FEE(), 10000);
    }

    /// @notice LOW_THRESHOLD が 30 であることを検証
    function test_LOW_THRESHOLD_is30() public view {
        assertEq(hook.LOW_THRESHOLD(), 30);
    }

    /// @notice HIGH_THRESHOLD が 70 であることを検証
    function test_HIGH_THRESHOLD_is70() public view {
        assertEq(hook.HIGH_THRESHOLD(), 70);
    }

    /// @notice コントラクトが IHooks インターフェースを実装していることを検証
    function test_implementsIHooks() public view {
        // IHooks にキャストできることを確認
        IHooks ihook = IHooks(address(hook));
        assertTrue(address(ihook) != address(0));
    }

    // ─── Task 2.2: getHookPermissions テスト ───

    /// @notice beforeSwap が true であることを検証
    function test_getHookPermissions_beforeSwapIsTrue() public view {
        Hooks.Permissions memory perms = hook.getHookPermissions();
        assertTrue(perms.beforeSwap, "beforeSwap should be true");
    }

    /// @notice beforeSwap 以外のすべてのフックが false であることを検証
    function test_getHookPermissions_allOtherPermissionsAreFalse() public view {
        Hooks.Permissions memory perms = hook.getHookPermissions();
        assertFalse(perms.beforeInitialize, "beforeInitialize should be false");
        assertFalse(perms.afterInitialize, "afterInitialize should be false");
        assertFalse(perms.beforeAddLiquidity, "beforeAddLiquidity should be false");
        assertFalse(perms.afterAddLiquidity, "afterAddLiquidity should be false");
        assertFalse(perms.beforeRemoveLiquidity, "beforeRemoveLiquidity should be false");
        assertFalse(perms.afterRemoveLiquidity, "afterRemoveLiquidity should be false");
        assertFalse(perms.afterSwap, "afterSwap should be false");
        assertFalse(perms.beforeDonate, "beforeDonate should be false");
        assertFalse(perms.afterDonate, "afterDonate should be false");
        assertFalse(perms.beforeSwapReturnDelta, "beforeSwapReturnDelta should be false");
        assertFalse(perms.afterSwapReturnDelta, "afterSwapReturnDelta should be false");
        assertFalse(perms.afterAddLiquidityReturnDelta, "afterAddLiquidityReturnDelta should be false");
        assertFalse(perms.afterRemoveLiquidityReturnDelta, "afterRemoveLiquidityReturnDelta should be false");
    }

    // ─── Task 2.3: calculateDynamicFee テスト ───

    /// @notice 稼働率 0 で LOW_FEE を返す（境界値: 最小）
    function test_calculateDynamicFee_utilization0_returnsLowFee() public view {
        assertEq(hook.calculateDynamicFee(0), 500);
    }

    /// @notice 稼働率 15 で LOW_FEE を返す（低稼働率の中間値）
    function test_calculateDynamicFee_utilization15_returnsLowFee() public view {
        assertEq(hook.calculateDynamicFee(15), 500);
    }

    /// @notice 稼働率 29 で LOW_FEE を返す（境界値: LOW_THRESHOLD - 1）
    function test_calculateDynamicFee_utilization29_returnsLowFee() public view {
        assertEq(hook.calculateDynamicFee(29), 500);
    }

    /// @notice 稼働率 30 で DEFAULT_FEE を返す（境界値: LOW_THRESHOLD）
    function test_calculateDynamicFee_utilization30_returnsDefaultFee() public view {
        assertEq(hook.calculateDynamicFee(30), 3000);
    }

    /// @notice 稼働率 50 で DEFAULT_FEE を返す（中稼働率の中間値）
    function test_calculateDynamicFee_utilization50_returnsDefaultFee() public view {
        assertEq(hook.calculateDynamicFee(50), 3000);
    }

    /// @notice 稼働率 69 で DEFAULT_FEE を返す（境界値: HIGH_THRESHOLD - 1）
    function test_calculateDynamicFee_utilization69_returnsDefaultFee() public view {
        assertEq(hook.calculateDynamicFee(69), 3000);
    }

    /// @notice 稼働率 70 で HIGH_FEE を返す（境界値: HIGH_THRESHOLD）
    function test_calculateDynamicFee_utilization70_returnsHighFee() public view {
        assertEq(hook.calculateDynamicFee(70), 10000);
    }

    /// @notice 稼働率 85 で HIGH_FEE を返す（高稼働率の中間値）
    function test_calculateDynamicFee_utilization85_returnsHighFee() public view {
        assertEq(hook.calculateDynamicFee(85), 10000);
    }

    /// @notice 稼働率 100 で HIGH_FEE を返す（境界値: 最大有効値）
    function test_calculateDynamicFee_utilization100_returnsHighFee() public view {
        assertEq(hook.calculateDynamicFee(100), 10000);
    }

    /// @notice 稼働率 101 で DEFAULT_FEE を返す（異常値フォールバック）
    function test_calculateDynamicFee_utilization101_returnsDefaultFee() public view {
        assertEq(hook.calculateDynamicFee(101), 3000);
    }

    /// @notice 稼働率 type(uint256).max で DEFAULT_FEE を返す（極端な異常値）
    function test_calculateDynamicFee_maxUint_returnsDefaultFee() public view {
        assertEq(hook.calculateDynamicFee(type(uint256).max), 3000);
    }
}
