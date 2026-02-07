// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "../src/lib/HookMiner.sol";

/// @notice HookMiner の internal 関数を external で公開するラッパー
contract HookMinerWrapper {
    function find(address deployer, uint160 flags, bytes memory creationCode, bytes memory constructorArgs, uint256 seed, uint256 maxIterations)
        external
        pure
        returns (address hookAddress, bytes32 salt)
    {
        return HookMiner.find(deployer, flags, creationCode, constructorArgs, seed, maxIterations);
    }
}

/// @title HookMinerTest
/// @notice Task 3.1: HookMiner ライブラリのテスト
contract HookMinerTest is Test {
    address constant DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    HookMinerWrapper wrapper;

    function setUp() public {
        wrapper = new HookMinerWrapper();
    }

    /// @notice find が有効なソルトとアドレスを返すことを検証
    function test_find_returnsValidSaltAndAddress() public pure {
        uint160 flags = Hooks.BEFORE_SWAP_FLAG;
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        (address hookAddress, bytes32 salt) = HookMiner.find(DEPLOYER, flags, creationCode, constructorArgs);

        assertTrue(hookAddress != address(0), "hookAddress should not be zero");
        assertTrue(salt != bytes32(0) || hookAddress != address(0), "salt or address should be set");
    }

    /// @notice 発見されたアドレスが正しいフラグビットを持つことを検証
    function test_find_addressHasCorrectFlags() public pure {
        uint160 flags = Hooks.BEFORE_SWAP_FLAG;
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        (address hookAddress,) = HookMiner.find(DEPLOYER, flags, creationCode, constructorArgs);

        // BEFORE_SWAP_FLAG ビットがセットされていること
        assertTrue(uint160(hookAddress) & flags == flags, "address should have BEFORE_SWAP_FLAG set");
    }

    /// @notice 発見されたアドレスが不要なフラグビットを持たないことを検証
    function test_find_addressHasNoExtraFlags() public pure {
        uint160 flags = Hooks.BEFORE_SWAP_FLAG;
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        (address hookAddress,) = HookMiner.find(DEPLOYER, flags, creationCode, constructorArgs);

        // ALL_HOOK_MASK 内で flags 以外のビットがセットされていないこと
        uint160 ALL_HOOK_MASK = uint160((1 << 14) - 1);
        assertEq(uint160(hookAddress) & ALL_HOOK_MASK, uint160(flags), "only requested flags should be set");
    }

    /// @notice カスタム seed と maxIterations で探索できることを検証
    function test_find_withSeedAndMaxIterations() public pure {
        uint160 flags = Hooks.BEFORE_SWAP_FLAG;
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        (address hookAddress,) = HookMiner.find(DEPLOYER, flags, creationCode, constructorArgs, 0, 2_000_000);

        assertTrue(uint160(hookAddress) & flags == flags, "address should have correct flags");
    }

    /// @notice maxIterations が不十分な場合に revert することを検証
    function test_find_revertsWhenSaltNotFound() public {
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        // 全14ビット (ALL_HOOK_MASK) を要求 — 100回では見つからない
        uint160 impossibleFlags = uint160((1 << 14) - 1);

        vm.expectRevert("HookMiner: salt not found");
        wrapper.find(DEPLOYER, impossibleFlags, creationCode, constructorArgs, 0, 100);
    }

    /// @notice computeAddress が正しい CREATE2 アドレスを計算することを検証
    function test_computeAddress_isCorrect() public pure {
        bytes32 salt = bytes32(uint256(1));
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        address computed = HookMiner.computeAddress(DEPLOYER, salt, creationCode, constructorArgs);

        // 手動計算と比較
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));
        address expected = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), DEPLOYER, salt, initCodeHash)))));

        assertEq(computed, expected, "computeAddress should match manual calculation");
    }

    /// @notice デフォルトの find (maxIterations = 1_000_000) が動作することを検証
    function test_find_defaultMaxIterations() public pure {
        uint160 flags = Hooks.BEFORE_SWAP_FLAG;
        bytes memory creationCode = type(DummyContract).creationCode;
        bytes memory constructorArgs = abi.encode(uint256(42));

        (address hookAddress, bytes32 salt) = HookMiner.find(DEPLOYER, flags, creationCode, constructorArgs);

        assertTrue(hookAddress != address(0) || salt != bytes32(0), "should find a valid result");
        assertTrue(uint160(hookAddress) & flags == flags, "flags should match");
    }
}

/// @notice テスト用ダミーコントラクト
contract DummyContract {
    uint256 public value;

    constructor(uint256 _value) {
        value = _value;
    }
}
