# ギャップ分析: Offchain Arbitrage Engine

## 分析サマリー

- **スコープ**: 複数L2のCPT価格監視、裁定機会検知、Yellow SDKによるガスレス高速裁定実行（Price Watcher + Arbitrage Engine + Yellow Session Manager）
- **現状**: スマートコントラクト層（CPT, UtilizationHook, Pool）は Base Sepolia・Sepolia・Unichain Sepolia に**デプロイ済み**。Arc 決済スクリプトも動作確認済み。**裁定エンジン関連のコードは一切未実装**
- **主な課題**: (1) WorldCoin Sepolia には Hook/Pool 未デプロイ（CPT+Oracle のみ）、(2) Yellow SDK 統合は未知数、(3) viem + Uniswap v4 価格読み取りパターン未確立
- **推奨アプローチ**: Option B（新規コンポーネント作成）+ モックファースト戦略
- **工数見積**: M〜L（5〜10日）、リスク: 中〜高

---

## 1. 現状調査（Current State Investigation）

### 1.1 既存アセット一覧

| カテゴリ | アセット | 状態 | 詳細 |
|----------|----------|------|------|
| **コントラクト** | ComputeToken (CPT) | ✅ デプロイ済み | 4チェーン。18 decimals, ERC20, Owner mint |
| **コントラクト** | UtilizationHook | ✅ デプロイ済み | Base Sepolia, Sepolia, Unichain Sepolia。beforeSwap で動的手数料 |
| **コントラクト** | MockOracle | ✅ デプロイ済み | 全チェーン。getUtilization() / setUtilization() |
| **コントラクト** | OperatorVault | ✅ デプロイ済み | Arc。USDC 入金/出金 |
| **Uniswap v4 Pool** | CPT/USDC Pool | ✅ 初期化済み | Base Sepolia, Sepolia, Unichain Sepolia に Pool ID あり |
| **スクリプト** | arc-transfer.ts | ✅ 動作済み | Circle Arc USDC 転送（curl ベース） |
| **スクリプト** | settle-to-vault.ts | ✅ 動作済み | Operator Vault へ USDC 決済 |
| **設定** | deployed-addresses.json | ✅ | 全コントラクトアドレス記録 |
| **設定** | usdc-addresses.json | ✅ | 各チェーンの USDC アドレス |
| **設定** | uniswap-v4-addresses.json | ✅ | PoolManager アドレス（Base Sepolia, Sepolia, Unichain Sepolia, Arbitrum Sepolia） |
| **ABI** | コンパイル済み | ✅ | `contract/out/` に全 ABI あり |
| **裁定エンジン** | Price Watcher | ❌ 未実装 | — |
| **裁定エンジン** | Arbitrage Engine | ❌ 未実装 | — |
| **裁定エンジン** | Yellow Session Manager | ❌ 未実装 | — |
| **依存パッケージ** | viem | ❌ 未インストール | — |
| **依存パッケージ** | @erc7824/nitrolite | ❌ 未インストール | — |
| **テストFW** | Vitest | ❌ 未インストール | — |

### 1.2 デプロイ済みアドレス（裁定エンジンが読み取る対象）

**Base Sepolia** (L2-A 候補):
- CPT: `0x68eBAd847A016bB830B3607e0eEeA516A09EA5e6`
- Hook: `0x038f554A1b854F68b3BB46125ea1947ffbf94080`
- Oracle: `0xe6230b8D99491dAd48e1de70156b4fd8b7b66b6f`
- Pool ID: `0x9c725b90d40af5c223a697bb4a489afe5ba1dd48ad0f95ee83344e3ea9505c26`
- PoolManager: `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

**WorldCoin Sepolia** (L2-B — 要件指定):
- CPT: `0x9eCE03F901dFC53544E4abf610b6813c6305f262`
- Oracle: `0xA0e9F77a3E1311301E5a29AEFfDa73113eD316E9`
- **Hook: なし** ⚠️
- **Pool ID: なし** ⚠️
- **PoolManager: 不明** ⚠️
- USDC: `0x66145f38cBAC35Ca6F1Dfb4914dF98F1614aeA88`

**Unichain Sepolia** (L2-B 代替候補):
- CPT: `0x67ADc29278d87D87b212C59fDffd2749fe7418c4`
- Hook: `0x079eC9842F78E5431F11AdD4a53d442192978080`
- Oracle: `0x9eCE03F901dFC53544E4abf610b6813c6305f262`
- Pool ID: `0x380b282aa0aee86e8a7ad653de14ff9eb087dcecde018f5d172ff192ed588082`
- PoolManager: `0x00b036b58a818b1bc34d502d3fe730db729e62ac`
- USDC: `0x31d0220469e10c4E71834a79b1f276d740d3768F`

### 1.3 既存パターンと規約

| 項目 | パターン |
|------|---------|
| ファイル名 | kebab-case（`arc-transfer.ts`, `settle-to-vault.ts`） |
| クラス名 | PascalCase + "Service" 接尾辞（`ArcTransferService`, `VaultSettlementService`） |
| インターフェース | PascalCase（`WalletBalance`, `TransferResult`, `SettlementResult`） |
| エラーハンドリング | try-catch + Error wrapping + `{success: boolean, error?: string}` 結果オブジェクト |
| 設定管理 | コンストラクタで `process.env` 読み込み + 即時バリデーション |
| ログ | `console.log` + 絵文字（✓, ✗）+ ステップ番号 |
| モジュール | ES Modules (`"type": "module"`) |
| TypeScript | strict: true, ES2020 target, ESNext modules |
| 実行 | `tsx` ランタイム（`pnpm transfer`, `pnpm settle`） |
| 外部API呼び出し | `execSync` で curl（非同期ではない）→ **新規実装では async/await 推奨** |

### 1.4 統合サーフェス

- **JSON 設定ファイル**: `contract/deployed-addresses.json`, `contract/usdc-addresses.json`, `contract/uniswap-v4-addresses.json` をインポート可能（`resolveJsonModule: true`）
- **ABI**: `contract/out/<Contract>.sol/<Contract>.json` から取得可能
- **Arc 決済パターン**: `settle-to-vault.ts` のフローを参照（Yellow セッション終了後の決済に利用）
- **UtilizationHook イベント**: `FeeOverridden(bytes32 indexed poolId, uint256 utilization, uint24 fee)` を監視可能

---

## 2. 要件実現可能性分析

### 2.1 Requirement 1: Price Watcher（価格差検知）

| AC# | 技術ニーズ | 現状 | ギャップタグ |
|-----|-----------|------|------------|
| AC1 | Base Sepolia CPT-A/USDC 価格取得 | Pool ID + PoolManager あり | **Missing**: viem client + slot0 読み取り |
| AC2 | WorldCoin Sepolia CPT-B/USDC 価格取得 | CPT + Oracle のみ | **Constraint**: Hook/Pool 未デプロイ |
| AC3 | 価格差閾値検知 → イベント発行 | なし | **Missing**: EventEmitter + 閾値設定 |
| AC4 | リトライロジック（3回） | リトライ実装なし | **Missing**: retry ユーティリティ |
| AC5 | エラーログ・アラート | console.log のみ | **Missing**: 構造化ロガー |
| AC6 | viem 使用 | 未インストール | **Missing**: `pnpm add viem` |
| AC7 | TypeScript strict mode | ✅ 設定済み | — |
| AC8 | 5秒ポーリング | なし | **Missing**: setInterval ループ |

**複雑性**: 中（外部統合: viem + Uniswap v4）

### 2.2 Requirement 2: Arbitrage Engine（裁定戦略生成）

| AC# | 技術ニーズ | 現状 | ギャップタグ |
|-----|-----------|------|------------|
| AC1 | 裁定機会イベント受信・分析 | なし | **Missing** |
| AC2 | Yellow セッション開始指示 | なし | **Missing** |
| AC3 | リスク管理ルール（中止判断） | なし | **Missing** |
| AC4 | 売買方向決定 | なし | **Missing** |
| AC5 | 取引数量計算 | なし | **Missing** |
| AC6 | 裁定戦略ログ | なし | **Missing** |
| AC7 | TypeScript strict mode | ✅ | — |

**複雑性**: 低〜中（純粋なビジネスロジック、外部依存なし）

### 2.3 Requirement 3: Yellow Session Manager（ガスレス裁定実行）

| AC# | 技術ニーズ | 現状 | ギャップタグ |
|-----|-----------|------|------------|
| AC1-2 | セッション開始・ID取得 | Skill ドキュメントあり | **Missing**: SDK 統合実装 |
| AC3 | オフチェーンマッチング | なし | **Missing**: NitroliteRPC 呼び出し |
| AC4 | 反復売買 | なし | **Missing** |
| AC5 | セッション終了・結果返却 | なし | **Missing** |
| AC6 | エラー時クローズ | なし | **Missing** |
| AC7 | Nitrolite SDK 使用 | 未インストール | **Missing**: `pnpm add @erc7824/nitrolite` |
| AC8 | ガスレス処理 | SDK 提供 | SDK 依存 |
| AC9 | モックフォールバック | なし | **Missing** |
| AC10 | `USE_YELLOW_MOCK` 切り替え | なし | **Missing** |

**複雑性**: 高（外部 SDK 統合、WebSocket、EIP-712 認証）

### 2.4 Requirement 4: Yellow SDK 調査

| AC# | 技術ニーズ | 現状 | ギャップタグ |
|-----|-----------|------|------------|
| AC1-3 | ドキュメント確認・サンプル検証 | Yellow Skill あり | **Research Needed** |
| AC4-6 | 統合可否判断・記録 | 未着手 | **Research Needed** |

### 2.5 Requirement 5: テスト・品質保証

| AC# | 技術ニーズ | 現状 | ギャップタグ |
|-----|-----------|------|------------|
| AC1-5 | コンポーネント別テスト | なし | **Missing** |
| AC6 | Vitest | 未インストール | **Missing** |
| AC7 | カバレッジレポート | なし | **Missing** |

### 2.6 Requirement 6: エラーハンドリング・ログ

| AC# | 技術ニーズ | 現状 | ギャップタグ |
|-----|-----------|------|------------|
| AC1-2 | エラーハンドリング | try-catch パターンあり | **Partial** |
| AC3 | JSON 構造化ログ | console.log のみ | **Missing** |
| AC4 | リトライロジック | なし | **Missing** |
| AC5 | アラート発行 | なし | **Missing** |
| AC6 | ログレベル | なし | **Missing** |

---

## 3. 実装アプローチオプション

### Option A: 既存コンポーネント拡張（scripts/ 直下にフラット配置）

**概要**: `scripts/price-watcher.ts` 等を既存スクリプトと同階層に配置

**Trade-offs**:
- ✅ ディレクトリ構造変更なし
- ✅ 既存 `package.json` scripts パターンに合致
- ❌ 3コンポーネント + モック + ユーティリティで scripts/ が肥大化
- ❌ コンポーネント間依存関係が見えにくい
- ❌ テスト配置が不明瞭

**評価**: 裁定エンジンは独立した責務群（Watcher → Engine → Yellow Session）で構成されるため、フラット配置は管理困難。

### Option B: 新規コンポーネント作成 ⭐推奨

**概要**: `scripts/arbitrage/` サブディレクトリに新規モジュール群を作成

```
scripts/
├── arbitrage/
│   ├── index.ts              # エントリーポイント（オーケストレーション）
│   ├── price-watcher.ts      # 価格監視（viem + Uniswap v4）
│   ├── arbitrage-engine.ts   # 裁定戦略生成
│   ├── yellow-session.ts     # Yellow SDK 統合（IYellowSession インターフェース）
│   ├── types.ts              # 共有型定義
│   ├── config.ts             # チェーン設定・閾値・アドレス
│   └── mock/
│       └── mock-yellow.ts    # Yellow モック実装（IYellowSession 準拠）
├── lib/
│   ├── logger.ts             # 構造化ロガー（JSON, ログレベル）
│   └── retry.ts              # リトライユーティリティ
├── __tests__/                # Vitest テスト
│   ├── price-watcher.test.ts
│   ├── arbitrage-engine.test.ts
│   ├── yellow-session.test.ts
│   └── integration.test.ts
├── arc-transfer.ts           # 既存（変更なし）
└── settle-to-vault.ts        # 既存（変更なし）
```

**Trade-offs**:
- ✅ 明確な責務分離
- ✅ IYellowSession インターフェースでモック/実装を DI 可能
- ✅ 各コンポーネントを独立テスト可能
- ✅ 既存スクリプトに一切影響なし
- ❌ 新規ファイル数が多い（10+ ファイル）
- ❌ インターフェース設計の初期コスト

**統合ポイント**:
- `config.ts` → `deployed-addresses.json`, `usdc-addresses.json` を読み込み
- `price-watcher.ts` → viem で PoolManager の slot0 を読み取り
- `yellow-session.ts` ← `USE_YELLOW_MOCK` 環境変数で実装/モック切り替え
- `index.ts` → `settle-to-vault.ts` パターンを参照（セッション終了後の決済）

### Option C: ハイブリッドアプローチ

**概要**: Option B + 既存スクリプトのリファクタリング（`lib/` の共有化）

**Trade-offs**:
- ✅ プロジェクト全体の一貫性向上
- ✅ `lib/logger.ts` を `arc-transfer.ts` 等からも利用可能
- ❌ 既存の動作中スクリプトに手を入れるリスク
- ❌ ハッカソンのスコープとしては過剰

**評価**: ハッカソンの時間制約を考えると、既存スクリプトのリファクタリングは不要。

---

## 4. 重要な制約と要調査事項

### 4.1 WorldCoin Sepolia の Uniswap v4 可用性 🔴 Critical

**問題**: `deployed-addresses.json` で `world-chain-sepolia` には `hook` と `poolId` が存在しない。`uniswap-v4-addresses.json` にも WorldCoin Sepolia の PoolManager アドレスがない。

**影響**: 要件 R1-AC2「WorldCoin Sepolia 上の CPT-B/USDC 価格を取得する」が実現不可能な可能性。

**選択肢**:
1. **WorldCoin Sepolia に Hook/Pool をデプロイする** — PoolManager の存在確認が前提
2. **チェーンペアを変更する** — Base Sepolia (L2-A) + Unichain Sepolia (L2-B) はどちらもフルデプロイ済み
3. **モック価格フィードを使う** — WorldCoin 側は MockOracle の `getUtilization()` から模擬価格を生成

> **Research Needed**: WorldCoin Sepolia での Uniswap v4 PoolManager 可用性

### 4.2 Uniswap v4 価格読み取り方法 🟡 Medium

**問題**: Uniswap v4 の PoolManager は v3 と異なり、singleton パターン。価格は `StateLibrary` 経由で `getSlot0(PoolId)` を読むか、`PoolManager` の `extsload` を使う。

**現状のヒント**: コントラクトの `InitializePool.s.sol` に `sqrtPriceX96` 計算ロジックがある。テスト (`PoolHookIntegration.t.sol`) に slot0 読み取りパターンがある可能性。

> **Research Needed**: viem での Uniswap v4 PoolManager `slot0` 読み取り ABI と `sqrtPriceX96` → 人間可読価格への変換

### 4.3 Yellow SDK 統合不確実性 🔴 High Risk

**問題**: `@erc7824/nitrolite` SDK の実動作は未検証。

**Skill ドキュメントからの情報**:
- パッケージ: `@erc7824/nitrolite`
- WebSocket: `wss://clearnet.yellow.com/ws`
- 認証: EIP-712 署名
- フロー: チャネル作成 → WebSocket 接続 → 認証 → セッション作成 → 操作 → クローズ

**緩和策**: 要件 R3-AC9, AC10 でモックフォールバックが明示。`USE_YELLOW_MOCK=true` で切り替え。

> **Research Needed**: `@erc7824/nitrolite` 最新バージョン、API 安定性、テストネット ClearNode 可用性

### 4.4 ABI 取得方法 🟢 Resolved

**解決済み**: `contract/out/` にコンパイル済み ABI あり。`resolveJsonModule: true` で JSON インポート可能。

**推奨**: 必要な ABI のみを `scripts/arbitrage/abi/` にコピーして使用（`contract/out/` は tsconfig の `include` 範囲外のため、直接インポートすると型エラーの可能性）。

---

## 5. 工数・リスク評価

### 全体評価

| 項目 | 値 | 根拠 |
|------|-----|------|
| **工数** | **M〜L（5〜10日）** | 3つの新規コンポーネント + Yellow SDK 調査 + テストスイート |
| **リスク** | **中〜高** | Yellow SDK 不確実性（モックで緩和）、WorldCoin Sepolia 制約 |

### コンポーネント別

| コンポーネント | 工数 | リスク | 根拠 |
|-------------|------|--------|------|
| Logger + Retry ユーティリティ | S (0.5日) | 低 | 標準パターン、外部依存なし |
| Config（チェーン設定・アドレス） | S (0.5日) | 低 | deployed-addresses.json 読み込み |
| Types（共有型定義） | S (0.5日) | 低 | インターフェース設計 |
| Price Watcher | M (1〜1.5日) | 中 | viem + Uniswap v4 slot0 読み取り調査 |
| Arbitrage Engine | S〜M (1日) | 低 | 純粋なビジネスロジック |
| Mock Yellow Session | S (0.5日) | 低 | ステートレスなシミュレーション |
| Yellow Session Manager (実装) | M〜L (1.5〜2日) | 高 | 外部 SDK 統合、WebSocket、EIP-712 |
| Entry Point + Orchestration | S (0.5日) | 低 | 各コンポーネントの結合 |
| テストスイート（Vitest） | M (1〜1.5日) | 中 | Vitest セットアップ + 単体/統合テスト |
| デバッグ・調整バッファ | S〜M (1日) | — | 想定外の問題対応 |

---

## 6. デザインフェーズへの推奨事項

### 6.1 推奨アプローチ

**Option B（新規コンポーネント作成）+ モックファースト戦略**

理由:
1. 裁定エンジンは既存スクリプトとは独立した責務群
2. モック/実装の DI 切り替えに Clean Architecture が最適
3. 3コンポーネント（Watcher → Engine → Yellow）のパイプラインが自然に表現可能
4. ハッカソンデモ要件（「動いている」ことの可視化）に合致

### 6.2 デザインフェーズで解決すべき事項

| # | 調査項目 | 優先度 | 備考 |
|---|---------|--------|------|
| 1 | WorldCoin Sepolia Uniswap v4 可用性 | 高 | チェーンペア最終決定に影響 |
| 2 | Uniswap v4 slot0 読み取り ABI（viem パターン） | 高 | Price Watcher の中核 |
| 3 | `@erc7824/nitrolite` インストール・接続テスト | 高 | Yellow Session の実現可否 |
| 4 | sqrtPriceX96 → 人間可読価格の変換ロジック | 中 | Price Watcher の価格比較 |
| 5 | コンポーネント間通信パターン（EventEmitter vs callback） | 中 | アーキテクチャ設計 |
| 6 | ABI 管理方法（コピー vs パスエイリアス） | 低 | ビルド設定 |
| 7 | 環境変数一覧の確定と `.env.example` 更新 | 低 | 設定管理 |

### 6.3 モックファースト実装順序（推奨）

```
Phase 1: 基盤ユーティリティ
  └─ Logger, Retry, Config, Types

Phase 2: モック裁定フロー（E2E 動作確認）
  └─ Mock Yellow → Arbitrage Engine → Price Watcher（モック価格）
  └─ Entry Point で全体オーケストレーション

Phase 3: 実チェーン統合
  └─ viem + Uniswap v4 価格読み取り（Price Watcher 実装）
  └─ Yellow SDK 統合（時間があれば）

Phase 4: テスト・品質保証
  └─ Vitest セットアップ → 単体テスト → 統合テスト → カバレッジ
```

### 6.4 依存する他仕様との関係

| 依存仕様 | 関係 | 現状 | 影響 |
|----------|------|------|------|
| uniswap-v4-integration | Pool 価格の読み取り元 | ✅ Base Sepolia 等にデプロイ済み | WorldCoin Sepolia のみ未完 |
| settlement-layer | Yellow セッション終了後の決済先 | ✅ Arc 決済スクリプト動作済み | 決済インターフェースの標準化が必要 |
| dashboard-demo | セッションログの表示先 | 未実装 | ログ形式（JSON 構造化）の事前合意が必要 |

### 6.5 追加する依存パッケージ

```bash
# 本番依存
pnpm add viem @erc7824/nitrolite

# 開発依存
pnpm add -D vitest @vitest/coverage-v8
```

---

**分析完了日**: 2026-02-07
**分析手法**: コードベース全体の探索（scripts/, contract/, root config）+ デプロイ済みアドレス確認 + Yellow Skill ドキュメント参照
**次ステップ**: `/kiro:spec-design offchain-arbitrage-engine` を実行してデザインドキュメントを作成
