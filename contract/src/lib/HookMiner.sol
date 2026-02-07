// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title HookMiner
/// @notice CREATE2 アドレスマイニングライブラリ
/// @dev v4-template の HookMiner を参考に実装
library HookMiner {
    /// @notice デフォルトの最大反復回数
    uint256 constant DEFAULT_MAX_ITERATIONS = 1_000_000;

    /// @notice 目的のフラグを持つアドレスとソルトを探索（デフォルト設定）
    /// @param deployer CREATE2 Deployer アドレス
    /// @param flags 必要な Hook フラグ（ビットマスク）
    /// @param creationCode コントラクトの creationCode
    /// @param constructorArgs コンストラクタ引数（エンコード済み）
    /// @return hookAddress 発見されたアドレス
    /// @return salt 使用するソルト
    function find(address deployer, uint160 flags, bytes memory creationCode, bytes memory constructorArgs)
        internal
        pure
        returns (address hookAddress, bytes32 salt)
    {
        return find(deployer, flags, creationCode, constructorArgs, 0, DEFAULT_MAX_ITERATIONS);
    }

    /// @notice 探索範囲を指定してアドレスを探索
    /// @param deployer CREATE2 Deployer アドレス
    /// @param flags 必要な Hook フラグ
    /// @param creationCode コントラクトの creationCode
    /// @param constructorArgs コンストラクタ引数
    /// @param seed 開始シード値
    /// @param maxIterations 最大反復回数
    /// @return hookAddress 発見されたアドレス
    /// @return salt 使用するソルト
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs,
        uint256 seed,
        uint256 maxIterations
    ) internal pure returns (address hookAddress, bytes32 salt) {
        uint160 ALL_HOOK_MASK = uint160((1 << 14) - 1);
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));

        for (uint256 i = seed; i < seed + maxIterations; i++) {
            salt = bytes32(i);
            hookAddress =
                address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));

            // アドレスの下位14ビット内で、要求フラグが全てセットされ、かつそれ以外のフラグがセットされていないことを確認
            if (uint160(hookAddress) & ALL_HOOK_MASK == flags) {
                return (hookAddress, salt);
            }
        }

        revert("HookMiner: salt not found");
    }

    /// @notice CREATE2 アドレスを計算する
    /// @param deployer CREATE2 Deployer アドレス
    /// @param salt ソルト値
    /// @param creationCode コントラクトの creationCode
    /// @param constructorArgs コンストラクタ引数
    /// @return addr 計算されたアドレス
    function computeAddress(address deployer, bytes32 salt, bytes memory creationCode, bytes memory constructorArgs)
        internal
        pure
        returns (address addr)
    {
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));
        addr = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }
}
