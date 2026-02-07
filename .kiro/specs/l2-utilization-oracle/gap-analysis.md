# ギャップ分析: l2-utilization-oracle

## 1. 現状調査

### 1.1 既存アセット一覧

| ファイル | 種別 | 現状 | 要件との関係 |
|----------|------|------|-------------|
| `contract/src/MockOracle.sol` | コントラクト | `IMockOracle` インターフェース + 単純な状態変数実装。`getUtilization()` / `setUtilization(uint256)` のみ。認可なし、メタデータなし | Req 1,2,3,4,8,9,10 の基盤。大幅拡張が必要 |
| `contract/src/hooks/UtilizationHook.sol` | コントラクト | `oracle.getUtilization()` で値取得→3段階fee計算。`DEFAULT_FEE=3000` 定義済み | Req 5 の基盤。メタ情報取得・stale判定を追加 |
| `contract/test/MockOracle.t.sol` | テスト | 基本4テスト（デフォルト値、範囲内設定、範囲外revert、イベント） | テスト大幅追加が必要 |
| `contract/test/UtilizationHook.t.sol` | テスト | 40以上のテスト（fee計算、権限、イベント） | stale判定テスト追加が必要 |
| `contract/test/PoolHookIntegration.t.sol` | テスト | E2Eテスト6件（実swap検証） | stale時の統合テスト追加 |
| `contract/script/DeployCore.s.sol` | デプロイ | MockOracle デプロイ含む | 拡張後のOracle対応が必要 |
| `contract/script/DeployHook.s.sol` | デプロイ | CREATE2 でHookデプロイ | oracle変更があれば再デプロイ |
| `contract/script/VerifyHookBehavior.s.sol` | 検証 | 3段階utilization検証 | stale検証シナリオ追加 |
| `scripts/` | オフチェーン | oracle-updater 未実装 | Req 6 で新規作成が必要 |
| Chainlink Functions 関連 | オフチェーン | 未実装 | Req 7 で新規作成が必要 |

### 1.2 既存パターンと規約

- **Solidity**: 0.8.26、Cancun EVM、Foundry フレームワーク
- **依存管理**: forge remappings（v4-core, v4-periphery, OpenZeppelin）
- **デプロイ**: 環境変数ベース（DEPLOYER_PRIVATE_KEY, CHAIN_NAME）、JSONファイルでアドレス管理
- **テスト**: forge test、境界値テスト重視、統合テストあり
- **アドレス管理**: `deployed-addresses.json` にチェーンごとのアドレスを記録
- **Hook パターン**: CREATE2 + HookMiner によるアドレスマイニング、immutable 引数

### 1.3 統合サーフェス

- **IMockOracle インターフェース**: `getUtilization()` と `setUtilization(uint256)` — Hook が依存
- **UtilizationHook コンストラクタ**: `IPoolManager` と `IMockOracle` を immutable で受け取り
- **デプロイスクリプト**: `deployed-addresses.json` からoracleアドレスを読み込み
- **Chainlink**: 現在未導入。foundry.toml にChainlink依存なし

---

## 2. 要件実現可能性分析

### 要件→既存アセットマッピング

| 要件 | 技術的ニーズ | 既存カバレッジ | ギャップ |
|------|-------------|---------------|---------|
| **Req 1: 稼働率指標** | EMA計算、メタデータ保存、`getUtilizationWithMeta()` | `getUtilization()` のみ。メタデータなし | **Missing**: `updatedAt`, `stale`, `source` フィールド。`getUtilizationWithMeta()` 関数 |
| **Req 2: ハイブリッド更新** | bot/Functions 二系統の更新関数 | `setUtilization(uint256)` のみ | **Missing**: `setUtilizationFromBot()`, `setUtilizationFromFunctions()`, 乖離検出ロジック |
| **Req 3: アクセス制御** | allowlistマッピング、管理者制限 | 認可チェックなし | **Missing**: allowlist管理、`Ownable` or カスタム権限モデル |
| **Req 4: TTL/Stale検出** | `staleTtl` 保存、stale判定ロジック | なし | **Missing**: TTL変数、stale計算ロジック、`setStaleTtl()` |
| **Req 5: Hook統合** | `getUtilizationWithMeta()` 呼び出し、stale時 `DEFAULT_FEE` | `getUtilization()` 呼び出し。`DEFAULT_FEE` は定義済み | **Constraint**: Hook は immutable で oracle を保持。インターフェース変更時は Hook 再デプロイ不要（同一アドレスのコントラクト差し替えで対応可能） |
| **Req 6: Bot更新** | TypeScript実装、EMA計算、RPC接続、定期実行 | 未実装 | **Missing**: `scripts/oracle-updater.ts` 全体 |
| **Req 7: Functions検証** | Chainlink Functions ソース、デプロイスクリプト | 未実装。Chainlink依存なし | **Missing**: Functions ソースコード、デプロイスクリプト、Router/Subscription設定 |
| **Req 8: 監査イベント** | source付きイベント、権限変更イベント | `UtilizationUpdated(uint256)` のみ（source なし） | **Missing**: イベント拡張（source, updatedAt 追加）、新規イベント2種 |
| **Req 9: 安全性** | タイムスタンプ検証、stale時安全挙動 | utilization > 100 の revert のみ | **Missing**: タイムスタンプバリデーション、初期stale状態 |
| **Req 10: 後方互換** | 既存関数シグネチャ維持 | 現行インターフェースが基準 | **Constraint**: `setUtilization(uint256)` シグネチャ維持必須。allowlistチェック追加のみ |
| **Req 11: 設定管理** | 設定ファイル、環境変数対応 | 未実装 | **Missing**: `config.ts` 全体 |

### 複雑性シグナル

- **Req 1-5, 8-10（オンチェーン）**: 既存コントラクトの拡張。パターンは確立済み（Foundry, OpenZeppelin）。中程度の複雑性
- **Req 6（Bot）**: 新規TypeScript実装だが、viem + RPC呼び出しの標準パターン。中程度
- **Req 7（Chainlink Functions）**: 外部依存の統合。Chainlink DON、Router、Subscription の知識が必要。**Research Needed**: Chainlink Functions の Sepolia 対応状況、コスト、レート制限
- **Req 2（乖離検出）**: bot値とFunctions値の比較ロジック。オンチェーンで前回値を保持する必要あり。設計判断が必要

---

## 3. 実装アプローチ候補

### Option A: 既存コンポーネント拡張

**概要**: `MockOracle.sol` を直接拡張し、新機能を追加する

**対象ファイル変更**:
- `contract/src/MockOracle.sol` — メタデータ、allowlist、TTL、新関数を追加
- `contract/src/hooks/UtilizationHook.sol` — `getUtilizationWithMeta()` 呼び出しに変更
- `contract/test/MockOracle.t.sol` — テスト大幅追加
- `contract/test/UtilizationHook.t.sol` — staleテスト追加

**互換性**: `IMockOracle` に新メソッドを追加（既存メソッドは維持）

**トレードオフ**:
- ✅ ファイル数最小、既存デプロイフローを活用
- ✅ 既存テスト基盤をそのまま拡張
- ✅ `deployed-addresses.json` のoracle枠をそのまま利用
- ❌ MockOracle という名前が実態と乖離する（リネームは破壊的変更）
- ❌ コントラクトの責務が膨らむ（Ownable + allowlist + TTL + Chainlink統合）

### Option B: 新規コンポーネント作成

**概要**: 新たに `L2UtilizationOracle.sol` + `IL2UtilizationOracle.sol` を作成し、`IMockOracle` も実装して後方互換性を確保

**新規ファイル**:
- `contract/src/L2UtilizationOracle.sol` — 本番オラクル
- `contract/src/interfaces/IL2UtilizationOracle.sol` — 拡張インターフェース
- `scripts/oracle-updater.ts` — Bot
- `scripts/arbitrage/functions/` — Chainlink Functions ソース + デプロイ
- `scripts/arbitrage/config.ts` — 設定ファイル

**統合方法**: `L2UtilizationOracle is IMockOracle` として既存Hook との互換性を維持。Hook再デプロイ時は新インターフェースを使用

**トレードオフ**:
- ✅ 責務が明確に分離される
- ✅ MockOracle はテスト用として残せる
- ✅ 名前が実態を正しく反映する
- ❌ ファイル数が増加
- ❌ Hook再デプロイが必要（immutable oracle アドレス変更のため）

### Option C: ハイブリッドアプローチ（推奨）

**概要**: 既存 `MockOracle.sol` を拡張しつつ名前は維持（後方互換性最優先）、オフチェーンは新規作成

**フェーズ分割**:

1. **Phase 1（オンチェーン基盤）**: `MockOracle.sol` を拡張
   - `IMockOracle` にメタデータ関数を追加
   - allowlist、TTL、stale検出、イベント拡張
   - UtilizationHook の stale 対応
   - テスト追加

2. **Phase 2（Bot更新）**: `scripts/oracle-updater.ts` 新規作成
   - EMA計算、RPC接続、定期更新
   - 設定ファイル作成

3. **Phase 3（Chainlink Functions）**: Functions統合
   - ソースコード、デプロイスクリプト
   - 乖離検出ロジック

**トレードオフ**:
- ✅ 段階的にデプロイ・検証可能
- ✅ Phase 1 だけでも価値提供（stale安全策）
- ✅ ハッカソンのタイムボックスに適合
- ❌ Phase間での整合性管理が必要

---

## 4. Research Needed（設計フェーズに持ち越し）

| 項目 | 理由 | 影響する要件 |
|------|------|-------------|
| Chainlink Functions の Base Sepolia / Unichain Sepolia 対応状況 | Router アドレスとSubscription可用性の確認が必要 | Req 7 |
| Chainlink Functions の実行コストとレート制限 | 15分間隔の定期実行のコスト見積もりが必要 | Req 7, 11 |
| FunctionsClient 継承パターン | Oracle が FunctionsClient を継承するか、別コントラクトで受信するかの設計判断 | Req 2, 7 |
| Hook 再デプロイの必要性 | IMockOracle インターフェース変更時に Hook の immutable oracle が影響を受けるか | Req 5, 10 |
| EMA 計算のオンチェーン vs オフチェーン | EMA計算をオンチェーンで行うかオフチェーンのみにするかの設計判断 | Req 1, 6 |
| 乖離検出のオンチェーン実装詳細 | bot最終値の保持方法、比較ロジックの粒度 | Req 2 |

---

## 5. 実装複雑性とリスク

### 工数見積もり

| フェーズ | 規模 | 根拠 |
|---------|------|------|
| Phase 1: オンチェーン基盤拡張 | **M（3-7日）** | 既存パターンの拡張だが、allowlist/TTL/stale/イベントと複数の新機能を追加。テスト追加も含む |
| Phase 2: Bot更新コンポーネント | **S（1-3日）** | viem + RPC の標準パターン。EMA計算はシンプル |
| Phase 3: Chainlink Functions統合 | **M（3-7日）** | 外部依存の統合。Router/Subscription設定、テスト環境構築が必要 |
| **合計** | **L（1-2週間）** | 3フェーズの合計 |

### リスク評価

| リスク | レベル | 説明 |
|--------|--------|------|
| Chainlink Functions 対応チェーン | **High** | Base Sepolia / Unichain Sepolia での Functions 可用性が未確認 |
| Hook 再デプロイ | **Medium** | インターフェース変更時に CREATE2 再マイニングとPool再作成が必要になる可能性 |
| EMA 精度 | **Low** | オフチェーン計算のため Solidity の固定小数点制約を受けない |
| Bot 可用性 | **Medium** | 単一Bot停止時のTTLによるセーフティネットはあるが、運用体制の確立が必要 |
| テスト複雑性 | **Low** | 既存テスト基盤が充実しており、パターンに従って拡張可能 |

---

## 6. 設計フェーズへの推奨事項

### 推奨アプローチ: Option C（ハイブリッド）

- **理由**: ハッカソンのタイムボックスに適合し、段階的デリバリーが可能。Phase 1 のみでも差別化に十分な価値を提供できる
- **重要判断事項**:
  1. `MockOracle` のリネーム可否（後方互換性 vs 命名の正確性）
  2. Chainlink FunctionsClient の統合パターン（Oracle直接継承 vs 中継コントラクト）
  3. Hook 再デプロイの回避戦略（インターフェースの追加的拡張で対応可能か）

### 持ち越しリサーチ項目
- Chainlink Functions の対象チェーン対応状況を設計フェーズ冒頭で確認
- FunctionsClient 統合パターンのベストプラクティスを調査
- 既存デプロイ済みコントラクトとの移行戦略を検討
