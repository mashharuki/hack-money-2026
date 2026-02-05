# Gap Analysis: Core Token System

**実施日**: 2026-02-06
**対象仕様**: core-token-system
**分析者**: AI Agent

---

## 📋 分析サマリー

### スコープ
Core Token System は、Zombie L2 Clearinghouse の基盤となる3つのスマートコントラクト（CPT Token, Mock Oracle, Operator Vault）とデプロイスクリプトの実装です。Base Sepolia, WorldCoin Sepolia, Arc の3チェーンへのデプロイが必要です。

### 主要な発見
- ✅ **Foundry環境が整備済み**: forge-std導入済み、基本的なテストパターン確立
- ✅ **既存スクリプトの活用可能**: Circle W3S API統合実装が scripts/ に存在
- ❌ **OpenZeppelin未導入**: ERC20, Ownable, ReentrancyGuard等の依存ライブラリが必要
- ❌ **マルチチェーンデプロイパターン未確立**: 3チェーン同時デプロイの自動化が必要
- ℹ️ **USDC Testnetアドレス要調査**: Base Sepolia, WorldCoin Sepolia, Arc のUSDCアドレス

### 推奨アプローチ
**Option B: 新規コンポーネント作成** - 既存のCounter.solはサンプルコードであり、本番用コントラクトは新規作成が適切。デプロイスクリプトも新規作成し、既存のarc-transfer.tsパターンを参考に実装。

### 工数・リスク
- **工数**: S (1-2日) - 標準的なERC20実装、シンプルなVaultロジック、Foundryパターン確立済み
- **リスク**: Low - 既知の技術スタック、明確な要件、OpenZeppelin活用で実装容易

---

## 1. 現状調査 (Current State Investigation)

### 1.1 既存アセット

#### Foundry プロジェクト構造
```
contract/
├── src/
│   └── Counter.sol          # サンプルコントラクト（削除予定）
├── script/
│   └── Counter.s.sol        # サンプルスクリプト（参考パターン）
├── test/
│   └── Counter.t.sol        # サンプルテスト（参考パターン）
├── lib/
│   └── forge-std/           # ✅ 導入済み
└── foundry.toml             # ✅ 基本設定済み
```

#### スクリプト（TypeScript）
```
scripts/
├── arc-transfer.ts          # ✅ Circle W3S API統合実装
└── settle-to-vault.ts       # ✅ Vault決済パターン実装
```

**活用可能な既存実装**:
- `arc-transfer.ts`: Circle Programmable Wallets API (W3S) による USDC 転送ロジック
- `settle-to-vault.ts`: Operator Vault への決済フローの参照実装
- これらは **settlement-layer 仕様** で活用されるが、環境変数パターンは本仕様でも参考可能

#### 設定ファイル
- `foundry.toml`: 基本設定済み（Solidity 0.8.13以上対応）
- `.env.example`: 環境変数テンプレート存在（詳細未確認）
- `package.json`: tsx, jose, typescript導入済み

### 1.2 既存パターン・規約

#### Solidity規約
- **バージョン**: `pragma solidity ^0.8.13;` （要件: 0.8.x以上 → ✅ 適合）
- **ライセンス**: `SPDX-License-Identifier: UNLICENSED`
- **インポート**: `import {Component} from "path";` 形式
- **NatSpec**: 要件で必須化されているが、既存サンプルには未実装

#### テストパターン
- **継承**: `contract CounterTest is Test`
- **setUp関数**: 初期化ロジック
- **命名**: `test_<FunctionName>`, `testFuzz_<FunctionName>`
- **アサーション**: `assertEq()` 使用

#### デプロイスクリプトパターン
- **継承**: `contract CounterScript is Script`
- **vm.broadcast()**: トランザクション実行
- **forge-std/Script.sol**: Foundry標準スクリプト基盤

#### ディレクトリ構成（ステアリング準拠）
- `contract/src/`: コントラクトソース
- `contract/test/`: Foundryテスト
- `contract/script/`: Foundryデプロイスクリプト
- `scripts/`: TypeScript運用スクリプト

### 1.3 統合ポイント

#### 他の仕様への接続
- **uniswap-v4-integration**: Mock Oracle が提供する稼働率データを使用
- **settlement-layer**: Operator Vault が USDC を受け取る（既存scripts活用）
- **dashboard-demo**: CPT Token と Operator Vault の状態を表示

#### 環境変数管理
既存の `.env.example` パターンを踏襲し、以下を追加予定:
```bash
# RPC URLs
BASE_SEPOLIA_RPC_URL=
WORLDCOIN_SEPOLIA_RPC_URL=
ARC_RPC_URL=

# Private Keys
DEPLOYER_PRIVATE_KEY=

# USDC Token Addresses (Testnet)
BASE_SEPOLIA_USDC=
WORLDCOIN_SEPOLIA_USDC=
ARC_USDC=
```

---

## 2. 要件実現性分析 (Requirements Feasibility Analysis)

### 2.1 技術要件マッピング

| 要件 | 必要な技術要素 | 既存資産 | ギャップ |
|------|--------------|---------|---------|
| **Req 1: CPT Token** | ERC20標準実装、Ownable、mint関数 | forge-std | OpenZeppelin未導入 ✘ |
| **Req 2: Mock Oracle** | Solidity状態変数、getter/setter | forge-std | なし（シンプル実装） ✓ |
| **Req 3: Operator Vault** | IERC20, Ownable, ReentrancyGuard | forge-std | OpenZeppelin未導入 ✘ |
| **Req 4: デプロイ** | Foundryスクリプト、JSON出力 | Counter.s.sol パターン | マルチチェーン対応必要 ⚠️ |
| **Req 5: エラーハンドリング** | Custom errors, revert, events | forge-std | パターン確立必要 ⚠️ |
| **Req 6: テスト** | Foundry test, カバレッジ | Counter.t.sol パターン | テストケース作成必要 ⚠️ |
| **Req 7: セキュリティ** | onlyOwner, ReentrancyGuard | - | OpenZeppelin未導入 ✘ |

### 2.2 ギャップと制約

#### 🔴 Missing: OpenZeppelin導入
**ギャップ**: OpenZeppelin Contractsライブラリが未導入
**影響**: ERC20, Ownable, ReentrancyGuard等の標準実装が利用不可
**対応**: `forge install OpenZeppelin/openzeppelin-contracts` で導入

#### 🟡 Constraint: マルチチェーンデプロイ
**ギャップ**: 3チェーン（Base Sepolia, WorldCoin Sepolia, Arc）への同時デプロイパターンが未確立
**影響**: 手動デプロイや複数スクリプト実行が必要になる可能性
**対応**: Foundryスクリプトで環境変数ベースのチェーン切り替え実装

#### 🟡 Research Needed: USDC Testnetアドレス
**ギャップ**: Base Sepolia, WorldCoin Sepolia, Arc の USDC コントラクトアドレスが不明
**影響**: Operator Vault のデプロイ時にアドレス指定が必要
**対応**: 設計フェーズで各チェーンの USDC アドレスを調査・記録

#### 🟢 Available: 既存スクリプトパターン
**資産**: `scripts/arc-transfer.ts`, `scripts/settle-to-vault.ts` が Circle W3S API 統合実装済み
**活用**: 環境変数管理パターン、エラーハンドリングパターンを参考可能

### 2.3 非機能要件の実現性

#### Performance
- **要件**: CPT Token mint/transfer < 100ms, Vault 入出金 1ブロック以内
- **実現性**: ✅ 標準的なERC20・Vault実装で達成可能（Ethereumベストプラクティス）

#### Security
- **要件**: onlyOwner, ReentrancyGuard, 環境変数管理
- **実現性**: ✅ OpenZeppelin活用で実現容易

#### Maintainability
- **要件**: NatSpec, TypeScript strict mode, ESLint/Prettier
- **実現性**: ✅ Foundry/TypeScript標準機能で対応可能

---

## 3. 実装アプローチオプション (Implementation Approach Options)

### Option A: 既存コンポーネント拡張
**評価**: ❌ 非推奨

**理由**:
- 既存の `Counter.sol` はサンプルコードであり、本番用コントラクトではない
- CPT Token, Mock Oracle, Operator Vault は独立したコントラクトとして新規作成が適切
- 既存コードの拡張では要件を満たせない

**Trade-offs**:
- ✅ なし（サンプルコードのため拡張不要）
- ❌ 既存コードは削除または別ディレクトリに移動

---

### Option B: 新規コンポーネント作成 ⭐ **推奨**
**評価**: ✅ 推奨

**新規作成コンポーネント**:

#### 1. CPT Token Contract (`src/CPTToken.sol`)
- OpenZeppelin ERC20 + Ownable を継承
- `mint(uint256 amount)` 関数実装（onlyOwner）
- NatSpec コメント付与

#### 2. Mock Oracle (`src/MockOracle.sol`)
- シンプルな状態変数 `uint256 private _utilization`
- `getUtilization()` と `setUtilization(uint256)` 実装
- 範囲検証（0-100%）

#### 3. Operator Vault (`src/OperatorVault.sol`)
- OpenZeppelin Ownable + ReentrancyGuard を継承
- IERC20 USDC トークンを管理
- `depositUSDC()`, `withdraw()`, `balanceOf()` 実装

#### 4. デプロイスクリプト (`script/DeployCore.s.sol`)
- 3チェーン対応（環境変数でチェーン切り替え）
- コントラクトアドレスをJSON出力
- エラーハンドリング実装

#### 5. テストスイート
- `test/CPTToken.t.sol`: mint, transfer, balanceOf
- `test/MockOracle.t.sol`: getUtilization, setUtilization
- `test/OperatorVault.t.sol`: depositUSDC, withdraw, balanceOf
- `test/Integration.t.sol`: CPT Token + Operator Vault 統合テスト

**統合ポイント**:
- `contract/src/` に新規コントラクトを配置
- `contract/script/` に新規デプロイスクリプトを配置
- `contract/test/` に新規テストを配置
- OpenZeppelin導入: `forge install OpenZeppelin/openzeppelin-contracts`

**責任範囲**:
- CPT Token: ERC20トークンの発行・転送
- Mock Oracle: 稼働率シグナル供給（他仕様で利用）
- Operator Vault: USDC収益管理（他仕様から入金）

**Trade-offs**:
- ✅ 明確な責任分離、テスト容易性
- ✅ OpenZeppelin活用で標準実装、セキュリティベストプラクティス準拠
- ✅ 他の仕様への依存なし、独立実装可能
- ❌ 新規ファイル作成が必要（ただし、構造は明確）

---

### Option C: ハイブリッドアプローチ
**評価**: ❌ 非推奨

**理由**:
- 本仕様は greenfield（新規実装）であり、ハイブリッドアプローチの必要性なし
- Option B（新規作成）で十分かつ明確

---

## 4. 実装複雑性とリスク (Implementation Complexity & Risk)

### 工数見積もり: S (1-2日)

**根拠**:
- **CPT Token**: OpenZeppelin ERC20 + Ownable 継承、mint 関数追加のみ（0.5日）
- **Mock Oracle**: シンプルな状態変数 + getter/setter（0.25日）
- **Operator Vault**: OpenZeppelin Ownable + ReentrancyGuard 継承、USDC入出金ロジック（0.5日）
- **デプロイスクリプト**: Foundryパターン確立済み、3チェーン対応（0.5日）
- **テスト**: 既存パターン活用、標準的なテストケース（0.5日）

### リスク: Low

**根拠**:
- **技術スタック**: Foundry, Solidity 0.8.x, OpenZeppelin - すべて確立済み
- **要件明確性**: ERC20, Vault, Oracle の要件は明確かつ標準的
- **統合リスク**: 他の仕様への依存なし、独立実装可能
- **セキュリティ**: OpenZeppelin活用でベストプラクティス準拠

**リスク要因**:
- 🟡 **USDC Testnetアドレス**: 設計フェーズで調査必要（調査時間 < 1時間）
- 🟡 **マルチチェーンデプロイ**: 初回実装時に動作確認が必要（テスト時間 < 2時間）
- 🟢 **OpenZeppelin導入**: `forge install` で即座に解決

---

## 5. 設計フェーズへの推奨事項 (Recommendations for Design Phase)

### 5.1 優先実装アプローチ
**Option B: 新規コンポーネント作成** を推奨

**実装順序**:
1. OpenZeppelin導入（`forge install`）
2. CPT Token Contract 実装（ERC20 + Ownable）
3. Mock Oracle 実装（シンプルな状態管理）
4. Operator Vault 実装（Ownable + ReentrancyGuard + USDC管理）
5. デプロイスクリプト実装（3チェーン対応）
6. テストスイート実装（単体テスト + 統合テスト）

### 5.2 要調査項目 (Research Items)

#### 1. USDC Testnetアドレス調査 🔍
**重要度**: High
**タイミング**: 設計フェーズ開始時
**調査内容**:
- Base Sepolia USDC コントラクトアドレス
- WorldCoin Sepolia USDC コントラクトアドレス
- Arc USDC コントラクトアドレス
- 各チェーンの Testnet Faucet情報

**調査方法**:
- Circle 公式ドキュメント確認
- Base, WorldCoin, Arc の公式ドキュメント確認
- Etherscan / Block Explorer でコントラクト検索

#### 2. Foundryマルチチェーンデプロイパターン確認 🔍
**重要度**: Medium
**タイミング**: デプロイスクリプト設計時
**調査内容**:
- Foundry での環境変数ベースのチェーン切り替え方法
- 複数チェーンへの順次デプロイ自動化
- デプロイ結果のJSON出力フォーマット

**調査方法**:
- Foundry Book ドキュメント確認
- `forge script --help` でオプション確認

### 5.3 技術的決定事項

#### OpenZeppelin依存関係
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

**バージョン**: 最新安定版（v5.x推奨、Solidity 0.8.x対応）

#### コントラクト配置
```
contract/src/
├── CPTToken.sol         # CPT Token Contract
├── MockOracle.sol       # Mock Oracle
└── OperatorVault.sol    # Operator Vault
```

#### デプロイスクリプト構成
```
contract/script/
└── DeployCore.s.sol     # 統合デプロイスクリプト（3チェーン対応）
```

#### 環境変数設定
`.env` ファイルに以下を追加:
```bash
# Core Token System
BASE_SEPOLIA_RPC_URL=
WORLDCOIN_SEPOLIA_RPC_URL=
ARC_RPC_URL=
DEPLOYER_PRIVATE_KEY=
BASE_SEPOLIA_USDC=
WORLDCOIN_SEPOLIA_USDC=
ARC_USDC=
```

### 5.4 既存資産の活用

#### 参考可能なパターン
- **デプロイスクリプト**: `contract/script/Counter.s.sol` の構造
- **テストパターン**: `contract/test/Counter.t.sol` の setUp/test 命名規則
- **環境変数管理**: `scripts/arc-transfer.ts` の環境変数読み込みパターン

#### 削除・移動対象
- `contract/src/Counter.sol` → 削除またはサンプルディレクトリに移動
- `contract/script/Counter.s.sol` → 削除またはサンプルディレクトリに移動
- `contract/test/Counter.t.sol` → 削除またはサンプルディレクトリに移動

---

## 6. 結論と次のステップ (Conclusion & Next Steps)

### Gap Analysis完了確認
✅ 現状調査完了
✅ 要件実現性分析完了
✅ 実装アプローチ評価完了
✅ 工数・リスク評価完了
✅ 設計フェーズ推奨事項作成完了

### 推奨される次のアクション

1. **Gap Analysis承認** (このドキュメント確認)
   - 推奨アプローチ: Option B（新規コンポーネント作成）
   - 工数: S (1-2日), リスク: Low

2. **設計フェーズ開始**
   ```bash
   /kiro:spec-design core-token-system
   ```
   - USDC Testnetアドレス調査を実施
   - 詳細な技術設計を作成

3. **または、自動承認して設計フェーズ開始**
   ```bash
   /kiro:spec-design core-token-system -y
   ```

### 成功基準の実現可能性
✅ **高い実現可能性**: 全7要件が標準的な技術スタックで実現可能
✅ **明確な実装パス**: OpenZeppelin活用、Foundryパターン確立済み
✅ **低リスク**: 既知の技術、明確な要件、独立実装可能

---

## 付録: 要件-資産マッピング詳細

| 要件ID | 要件名 | 必要な実装 | 既存資産 | ギャップ | 優先度 |
|--------|--------|-----------|---------|---------|--------|
| Req 1.1-1.7 | CPT Token | ERC20, Ownable, mint | forge-std | OpenZeppelin未導入 | P0 |
| Req 2.1-2.6 | Mock Oracle | 状態変数, getter/setter | forge-std | なし | P0 |
| Req 3.1-3.7 | Operator Vault | Ownable, ReentrancyGuard, IERC20 | forge-std | OpenZeppelin未導入 | P0 |
| Req 4.1-4.6 | デプロイ | Foundryスクリプト, JSON出力 | Counter.s.sol パターン | マルチチェーン対応 | P0 |
| Req 5.1-5.4 | エラーハンドリング | Custom errors, events | forge-std | パターン確立 | P1 |
| Req 6.1-6.6 | テスト | Foundry test, カバレッジ | Counter.t.sol パターン | テストケース作成 | P1 |
| Req 7.1-7.6 | セキュリティ | onlyOwner, ReentrancyGuard | - | OpenZeppelin未導入 | P0 |

**凡例**:
- P0: 必須（MVP実装に必須）
- P1: 重要（品質保証に重要）

---

**Gap Analysis完了**: 設計フェーズに進む準備が整いました。
