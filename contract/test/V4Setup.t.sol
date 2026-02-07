// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";

/// @title V4SetupTest
/// @notice Uniswap v4 依存関係のセットアップ検証テスト
contract V4SetupTest is Test {
    using PoolIdLibrary for PoolKey;

    /// @notice v4-core のインポートが正しく動作することを検証
    function test_v4CoreImportsCompile() public pure {
        // Hooks ライブラリのフラグが定義されていることを確認
        uint256 flag = Hooks.BEFORE_SWAP_FLAG;
        assertGt(flag, 0, "BEFORE_SWAP_FLAG should be non-zero");
    }

    /// @notice PoolKey の構築と PoolId の生成が動作することを検証
    function test_poolKeyAndIdGeneration() public pure {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(1)),
            currency1: Currency.wrap(address(2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        PoolId id = key.toId();
        assertTrue(PoolId.unwrap(id) != bytes32(0), "PoolId should be non-zero");
    }

    /// @notice BeforeSwapDelta のゼロ値が正しく動作することを検証
    function test_beforeSwapDeltaZero() public pure {
        BeforeSwapDelta delta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        assertEq(BeforeSwapDelta.unwrap(delta), 0, "ZERO_DELTA should be zero");
    }

    /// @notice EVM cancun (transient storage) が有効であることを検証
    function test_evmCancunEnabled() public {
        // transient storage (EIP-1153) の基本動作確認
        // tstore/tload が使えればコンパイル・実行できる
        assembly {
            tstore(0, 42)
            let val := tload(0)
            if iszero(eq(val, 42)) { revert(0, 0) }
        }
    }
}
