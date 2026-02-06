# ギャップ分析: Uniswap v4 Integration

## 分析概要

本ドキュメントは、`uniswap-v4-integration` 仕様の要件と既存コードベースの間のギャップを分析し、実装戦略を検討する。

### 分析サマリー

- **スコープ**: Uniswap v4 Pool + Utilization Hook の実装、CREATE2 + HookMiner デプロイ
- **主要課題**: Uniswap v4 依存関係の導入、Hook アドレスビットパターン制約対応
- **複雑度**: M-L（新規ライブラリ導入 + 複雑な統合）
- **リスク**: 中（未使用技術、アドレスマイニング要件）
- **推奨アプローチ**: Option B（新規コンポーネント作成）

---

## 1. 現状調査（Current State Investigation）

### 1.1 既存コードベース構造

```
contract/
├── src/
│   └── Counter.sol          # サンプル（削除予定）
├── script/
│   └── Counter.s.sol         # サンプル（削除予定）
├── test/
│   └── Counter.t.sol         # サンプル（削除予定）
├── lib/
│   └── forge-std/            # Foundry 標準ライブラリのみ
└── foundry.toml              # 基本設定
```

### 1.2 依存関係

**現状**:
- `forge-std` のみ導入済み
- Uniswap v4-core / v4-periphery **未導入**
- OpenZeppelin **未導入**（core-token-system で導入予定）

**必要な追加依存**:
- `v4-core`: IPoolManager, Hooks, PoolKey, BalanceDelta 等
- `v4-periphery`: BaseHook, StateLibrary 等
- `OpenZeppelin`: Ownable（Hook 管理用）

### 1.3 関連仕様の状態

| 仕様 | 状態 | 提供するもの |
|------|------|-------------|
| core-token-system | design 完了 | CPT Token, Mock Oracle |
| uniswap-v4-integration | requirements 完了 | **本仕様** |
| settlement-layer | 未着手 | USDC 決済 |
| offchain-arbitrage-engine | requirements 完了 | 価格監視 |

**依存関係**:
- Mock Oracle（core-token-system）→ Utilization Hook が稼働率を取得
- CPT Token（core-token-system）→ Pool の片側トークン

### 1.4 Uniswap v4 テストネット環境

| ネットワーク | Chain ID | PoolManager アドレス |
|-------------|----------|---------------------|
| **Base Sepolia** | 84532 | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| Arbitrum Sepolia | 421614 | `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` |

**注意**: World Chain Sepolia の PoolManager アドレスは公式ドキュメントで確認できず、リサーチが必要。

---

## 2. 要件実現可能性分析

### 2.1 要件マッピング

| 要件 | 技術要素 | 既存資産 | ギャップ |
|------|---------|----------|---------|
| R1: CPT/USDC Pool | Uniswap v4 Pool 初期化 | なし | **Missing** |
| R2: Utilization Hook | beforeSwap, 動的手数料 | なし | **Missing** |
| R2.9: CREATE2 + HookMiner | アドレスマイニング | なし | **Missing** |
| R3: デプロイスクリプト | Foundry Script | Counter.s.sol（参考） | **Partial** |
| R4: テストスイート | Foundry Test | Counter.t.sol（参考） | **Partial** |
| R5: セキュリティ | onlyPoolManager, ReentrancyGuard | なし | **Missing** |

### 2.2 技術的要件

#### Utilization Hook 実装

```solidity
// 必要なインターフェース
function beforeSwap(
    address sender,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    bytes calldata hookData
) external returns (bytes4, BeforeSwapDelta, uint24);
```

**動的手数料計算ロジック**:
```
稼働率 0-30%   → 低手数料 (0.05%)
稼働率 30-70%  → 標準手数料 (0.3%)
稼働率 70-100% → 高手数料 (1.0%)
```

#### Hook アドレスビットパターン

Uniswap v4 は Hook アドレスの下位 14 ビットで有効なフック関数を判定:

| ビット位置 | フラグ | 必要性 |
|-----------|--------|--------|
| 7 | BEFORE_SWAP_FLAG | ✅ 必須 |
| 8 | AFTER_SWAP_FLAG | ❌ オプション |

**必要なビットパターン**: `0x80` 以上（beforeSwap 有効化）

#### CREATE2 + HookMiner パターン

```solidity
// HookMiner でソルト探索
(address hookAddress, bytes32 salt) = HookMiner.find(
    CREATE2_DEPLOYER,
    uint160(Hooks.BEFORE_SWAP_FLAG), // 必要なフラグ
    type(UtilizationHook).creationCode,
    abi.encode(poolManager, mockOracle)
);
```

### 2.3 制約事項

1. **Hook アドレス制約**: デプロイ前にソルト探索が必要（計算コスト）
2. **PoolManager 依存**: 各チェーンで異なる PoolManager アドレス
3. **USDC 依存**: 各チェーンの USDC アドレスが必要
4. **Mock Oracle 依存**: core-token-system との連携必須

### 2.4 Research Needed

- [ ] World Chain Sepolia の Uniswap v4 PoolManager アドレス（公式未確認）
- [ ] Base Sepolia / World Chain Sepolia の USDC 流動性ソース
- [ ] HookMiner Solidity 実装の最新バージョン確認
- [ ] v4-core / v4-periphery の正確なバージョン選定

---

## 3. 実装アプローチオプション

### Option A: 既存コンポーネント拡張

**該当なし** - Uniswap v4 関連の既存資産がないため不適用。

---

### Option B: 新規コンポーネント作成（推奨）

**根拠**:
- Uniswap v4 統合は独立した責任領域
- 既存コードベースが空に近い状態
- Hook は専用のセキュリティパターンが必要

**作成するコンポーネント**:

| コンポーネント | 配置先 | 役割 |
|---------------|--------|------|
| UtilizationHook.sol | src/ | 動的手数料制御 Hook |
| HookMiner.sol | src/lib/ | CREATE2 ソルト探索 |
| PoolInitializer.sol | src/ | Pool 初期化ヘルパー |
| DeployHook.s.sol | script/ | Hook デプロイスクリプト |
| InitializePool.s.sol | script/ | Pool 初期化スクリプト |
| UtilizationHook.t.sol | test/ | Hook 単体テスト |
| PoolIntegration.t.sol | test/ | Pool + Hook 統合テスト |

**統合ポイント**:
- Mock Oracle → UtilizationHook: `getUtilization()` 呼び出し
- CPT Token → Pool: currency0 として使用
- USDC → Pool: currency1 として使用

**トレードオフ**:
- ✅ 明確な責任分離
- ✅ 独立したテスト可能性
- ✅ core-token-system との疎結合
- ❌ 新規ファイル数が多い
- ❌ インターフェース設計が必要

---

### Option C: ハイブリッドアプローチ

**該当なし** - 拡張対象の既存コンポーネントがないため不適用。

---

## 4. 実装複雑度とリスク

### 4.1 工数見積もり

**M-L（5-10日）**

| 作業 | 見積もり |
|------|---------|
| 依存関係導入・設定 | 0.5日 |
| UtilizationHook 実装 | 1.5日 |
| HookMiner 統合 | 1日 |
| デプロイスクリプト | 1日 |
| 単体テスト | 1.5日 |
| 統合テスト | 1日 |
| テストネットデプロイ・検証 | 1.5日 |
| デバッグ・調整バッファ | 2日 |

**根拠**:
- 新規ライブラリ導入（v4-core, v4-periphery）
- CREATE2 + HookMiner パターンの習熟
- マルチチェーンデプロイの複雑性

### 4.2 リスク評価

**リスクレベル: 中**

| リスク | 影響 | 対策 |
|--------|------|------|
| Hook アドレスマイニング失敗 | 高 | ソルト探索範囲拡大、事前テスト |
| v4-core バージョン互換性 | 中 | 公式テンプレート参照、バージョン固定 |
| World Chain Sepolia 未対応 | 中 | Base Sepolia 優先、代替チェーン検討 |
| Mock Oracle 統合問題 | 低 | インターフェース事前定義 |
| ガス制限超過 | 低 | 最小限のロジック、ベンチマーク |

---

## 5. デザインフェーズへの推奨事項

### 5.1 推奨アプローチ

**Option B（新規コンポーネント作成）を採用**

理由:
1. 既存資産がなく、拡張対象が存在しない
2. Uniswap v4 Hook は独自のセキュリティパターンを必要とする
3. core-token-system との疎結合が望ましい

### 5.2 重要な設計決定

1. **Hook 権限範囲**: beforeSwap のみ vs beforeSwap + afterSwap
2. **手数料計算式**: 線形 vs 段階的 vs 曲線
3. **フォールバック手数料**: 異常時のデフォルト値
4. **イベントログ**: 稼働率・手数料変更の記録方式

### 5.3 Research Carried Forward

以下はデザインフェーズで調査・解決が必要:

1. **World Chain Sepolia 対応**
   - Uniswap v4 が未デプロイの可能性
   - 代替: Base Sepolia + Arbitrum Sepolia の2チェーン構成

2. **HookMiner 実装選定**
   - v4-template 内の HookMiner.sol を使用するか
   - カスタム実装が必要か

3. **USDC 流動性確保**
   - Testnet USDC の入手方法
   - 初期流動性提供量の決定

### 5.4 依存関係チェックリスト

**デザインフェーズ開始前に確認**:
- [ ] core-token-system の Mock Oracle インターフェース確定
- [ ] OpenZeppelin の導入（core-token-system と共有）
- [ ] 対象チェーンの最終決定

---

## 付録: Uniswap v4 技術リファレンス

### A.1 Hook ビットフラグ

```solidity
uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
uint160 constant AFTER_SWAP_FLAG = 1 << 8;
// 本仕様では BEFORE_SWAP_FLAG が必須
```

### A.2 PoolManager アドレス

```
Base Sepolia:     0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
Arbitrum Sepolia: 0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317
CREATE2 Deployer: 0x4e59b44847b379578588920ca78fbf26c0b4956c
```

### A.3 推奨 Foundry 依存関係

```bash
forge install Uniswap/v4-core
forge install Uniswap/v4-periphery
forge install OpenZeppelin/openzeppelin-contracts
```

### A.4 Hook テンプレート構造

```solidity
contract UtilizationHook is BaseHook {
    IMockOracle public immutable oracle;

    constructor(IPoolManager _pm, IMockOracle _oracle) BaseHook(_pm) {
        oracle = _oracle;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeSwap: true,
            // 他は false
        });
    }

    function beforeSwap(...) external override returns (bytes4, BeforeSwapDelta, uint24) {
        uint256 utilization = oracle.getUtilization();
        uint24 fee = calculateDynamicFee(utilization);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee);
    }
}
```

---

**分析完了日**: 2026-02-06
**次ステップ**: `/kiro:spec-design uniswap-v4-integration` を実行してデザインドキュメントを作成
