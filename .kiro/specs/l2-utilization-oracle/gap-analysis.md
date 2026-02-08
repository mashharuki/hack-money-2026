# ギャップ分析: l2-utilization-oracle

## Analysis Summary
- 現状はオンチェーン／オフチェーン双方の基盤がすでに実装されており、要件の大部分はカバー済み
- 残ギャップは「Functions 定期実行の運用経路」「Functions 値の記録粒度」「設定値の反映一貫性」に集中
- 既存構成を拡張するだけで完成度を上げられるため、短時間で改善可能な打ち手が多い
- 最優先は `setUtilizationFromFunctions()` のメタ記録と Functions 運用スクリプト/自動化の不足解消
- 期限内の品質向上は「設定整合性の修正 + 運用経路の明文化」で達成しやすい

## Document Status
本書は `requirements.md` と現行コードベースを突き合わせ、`gap-analysis.md` のフレームワークに従って更新済み。

## Next Steps
1. 設計フェーズの更新が必要なら `/kiro:spec-design l2-utilization-oracle` を実行
2. 直近3時間スコープでの改善を優先するなら「ギャップ上位3点」を短期タスク化

---

## 1. 現状調査

### 1.1 既存アセット一覧

| ファイル | 種別 | 現状 | 要件との関係 |
|----------|------|------|-------------|
| `contract/src/MockOracle.sol` | コントラクト | allowlist、TTL、stale判定、乖離検出、Functions/Bot更新、イベント発行まで実装済み | Req 1,2,3,4,8,9,10 を概ね満たす基盤 |
| `contract/src/hooks/UtilizationHook.sol` | コントラクト | `getUtilizationWithMeta()` を参照し stale 時に `DEFAULT_FEE` へフォールバック | Req 5 を満たす |
| `contract/src/functions/FunctionsReceiver.sol` | コントラクト | Functions Router 受信 + `setUtilizationFromFunctions()` 呼び出しを実装。Upkeep 間隔あり | Req 7 の受信側を部分的に満たす |
| `scripts/arbitrage/oracle-updater.ts` | スクリプト | EMA計算、RPCフォールバック、定期更新を実装 | Req 6 を満たす |
| `scripts/arbitrage/functions/source.js` | Functions | EMA計算 + RPCフォールバック実装 | Req 7(1) を満たす |
| `scripts/arbitrage/functions/config.ts` | 設定 | Functions 引数生成のユーティリティ | Req 7/11 の一部を満たす |
| `scripts/arbitrage/functions/deploy/*` | 設定 | Base Sepolia のデプロイ設定生成のみ | Req 7(4) を部分的に満たす |
| `scripts/arbitrage/config.ts` | 設定 | RPC/EMA/TTL/乖離閾値/Functions設定の読み込み | Req 11 を満たす（ただし未使用項目あり） |
| `contract/test/*` | テスト | FunctionsReceiver/Hook/Pool の統合テストあり | Req 5,7 の検証基盤 |

### 1.2 既存パターンと規約

- **Solidity**: 0.8.26、Foundry + OpenZeppelin
- **Hook**: CREATE2 + HookMiner でアドレスマイニング
- **設定**: JSON + 環境変数（`scripts/arbitrage/config.ts`）
- **オフチェーン**: `viem` + `tsx` でRPC取得・トランザクション送信

### 1.3 統合サーフェス

- **Oracle API**: `IMockOracle` が Hook/FunctionsReceiver から参照
- **Functions Receiver**: Router 経由で `setUtilizationFromFunctions()` へ連携
- **Bot Update**: `setUtilizationFromBot()` を直接呼び出し
- **Config**: Oracle/Bot/Functions の設定値が同一ファイルに集中

---

## 2. 要件実現可能性分析

### 要件→既存アセットマッピング

| 要件 | 技術的ニーズ | 既存カバレッジ | ギャップ |
|------|-------------|---------------|---------|
| **Req 1: 稼働率指標** | EMA値の保存、メタ返却 | `MockOracle` に `getUtilizationWithMeta()` 実装済み | **Constraint**: EMAはオフチェーン計算のみ（要件上は許容） |
| **Req 2: ハイブリッド更新** | bot/Functions併用、乖離判定 | 乖離判定 + 2系統更新は実装済み | **Missing**: Functions 側の `timestamp` 記録フィールドがない | 
| **Req 3: アクセス制御** | allowlist + owner | `setAuthorizedUpdater()` + `onlyAuthorizedUpdater` 実装済み | **OK** |
| **Req 4: TTL/Stale検出** | TTL保持、stale判定 | `_staleTtl` + stale 判定実装済み | **OK** |
| **Req 5: Hook統合** | メタ取得 + stale fallback | UtilizationHook が対応済み | **OK** |
| **Req 6: Bot更新** | EMA計算、RPCフォールバック、定期実行 | `oracle-updater.ts` で実装済み | **OK** |
| **Req 7: Functions検証** | Functionsソース、定期実行、デプロイ支援 | `source.js` は実装済み | **Missing**: 15分実行の運用経路と登録スクリプト | 
| **Req 8: 監査イベント** | 更新・権限・TTLイベント | `UtilizationUpdated`/`UpdaterAuthorizationChanged`/`TtlUpdated` あり | **OK** |
| **Req 9: 安全性** | 未来/古すぎるtimestampの拒否 | `_validateTimestamp()` 実装済み | **OK** |
| **Req 10: 後方互換** | `setUtilization()` 維持 | シグネチャ維持済み | **OK** |
| **Req 11: 設定管理** | env + chain別設定 | `loadOracleConfig()` 実装済み | **Constraint**: `divergenceThreshold`/`staleTtl` が未適用 |

### 複雑性シグナル

- **オンチェーン**: 既に完了に近く、残作業は小粒（S〜M）
- **Functions 運用**: 実行経路の自動化が不足（M）
- **設定反映**: コードと設定値の乖離が品質低下の主因（S）

---

## 3. 実装アプローチ候補

### Option A: 既存コンポーネント拡張（最短改善）

**概要**: `MockOracle.sol` と `FunctionsReceiver.sol` を最小変更し、設定整合性と運用経路を補完

**対象ファイル**:
- `contract/src/MockOracle.sol`（Functions timestamp 追加、乖離閾値の外部化 など）
- `contract/src/functions/FunctionsReceiver.sol`（デフォルト間隔の整合）
- `scripts/arbitrage/functions/deploy/*`（登録/更新スクリプト）

**トレードオフ**:
- ✅ 既存構造を維持でき、短時間で品質向上が可能
- ✅ Hook 再デプロイ不要
- ❌ `MockOracle` の役割が引き続き多機能

### Option B: 運用系のみ分離

**概要**: コントラクトは最小変更に留め、Functions 運用と設定の自動化を別モジュール化

**対象**:
- `scripts/arbitrage/functions/` にデプロイ/更新のCLIを追加
- `scripts/arbitrage/oracle-updater.ts` に Functions 実行スケジューラを追加

**トレードオフ**:
- ✅ コントラクト改修を抑制
- ✅ 3時間スコープで達成可能
- ❌ オンチェーンの記録粒度改善は別途必要

### Option C: ハイブリッド（推奨）

**概要**: オンチェーンの不足メタ情報だけ追加し、運用系は自動化を強化

**トレードオフ**:
- ✅ 短時間でも品質向上とデモ信頼性が両立
- ✅ リスクが低く、影響範囲が明確
- ❌ 小さな改修が複数に分散

---

## 4. Research Needed

| 項目 | 理由 | 影響する要件 |
|------|------|-------------|
| Functions 定期実行の現実運用（Automation/Custom） | 15分実行の具体手段が未決 | Req 7 |
| Base Sepolia DON/Router の最新値 | 定数が固定値で古い可能性 | Req 7 |

---

## 5. 実装複雑性とリスク

### 工数見積もり

| 項目 | 規模 | 根拠 |
|------|------|------|
| Functions 運用経路の補完 | **S（1-3日）** | CLI/README 追加で改善可能 |
| Oracle メタ追加 | **S（1-3日）** | 1ファイルの軽微修正 |
| 設定値の整合 | **S（1-3日）** | config とコントラクト定数の統一 |

### リスク評価

| リスク | レベル | 説明 |
|--------|--------|------|
| Functions 運用の不確実性 | **Medium** | 手動実行だと安定性が不足する可能性 |
| 設定乖離 | **Low** | 小改修で解消可能 |

---

## 6. 設計フェーズへの推奨事項

### 推奨アプローチ
**Option C（ハイブリッド）**

### 重点改善（3時間スコープ）
1. `setUtilizationFromFunctions()` に Functions 側の `timestamp` 記録を追加
2. `FunctionsReceiver` のデフォルト Upkeep 間隔を要件（15分）に整合
3. Functions ソース登録・args更新・performUpkeep 実行までを一気通貫で行うスクリプト/手順を用意
4. `divergenceThreshold` / `staleTtl` の設定値をコントラクトに反映する運用手順を追記

### 持ち越しリサーチ
- Functions の自動実行は Automation 連携か、外部 cron かを決める
- Unichain Sepolia 側の Functions 対応可否を確認
