# Research & Design Decisions: Uniswap v4 Integration

---
**Purpose**: Uniswap v4 Hook 実装に関する技術調査と設計決定を記録
**Discovery Scope**: Complex Integration（新規ライブラリ導入 + 外部プロトコル統合）
---

## Summary

- **Feature**: `uniswap-v4-integration`
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  1. Uniswap v4 Hook は CREATE2 + HookMiner パターンでアドレスビットパターン制約に対応必須
  2. Base Sepolia に PoolManager がデプロイ済み（`0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`）
  3. 動的手数料は `beforeSwap` フックで `OVERRIDE_FEE_FLAG` を返すことで実現可能
  4. World Chain Sepolia は Uniswap v4 未デプロイの可能性が高く、代替チェーン検討が必要

---

## Research Log

### Uniswap v4 Hook インターフェース

- **Context**: Utilization Hook の実装に必要なインターフェースと機能を調査
- **Sources Consulted**:
  - [Uniswap v4 Hooks Documentation](https://docs.uniswap.org/contracts/v4/concepts/hooks)
  - [IHooks Interface Reference](https://docs.uniswap.org/contracts/v4/reference/core/interfaces/IHooks)
  - プロジェクト内スキル `.claude/skills/uniswap-dev/references/v4-hooks.md`
- **Findings**:
  - `beforeSwap` フックは `(bytes4, BeforeSwapDelta, uint24)` を返す
  - 動的手数料は第3戻り値（uint24）で指定し、`OVERRIDE_FEE_FLAG` を OR することで有効化
  - Hook アドレスの下位14ビットで有効なフック関数を判定
  - `BEFORE_SWAP_FLAG = 1 << 7` が本仕様で必須
- **Implications**:
  - UtilizationHook は `beforeSwap` のみ実装すれば要件を満たす
  - アドレスパターン `0x80` 以上（ビット7がセット）が必要

### CREATE2 + HookMiner パターン

- **Context**: Hook アドレスビットパターン制約への対応方法を調査
- **Sources Consulted**:
  - [Hook Deployment Guide](https://docs.uniswap.org/contracts/v4/guides/hooks/hook-deployment)
  - [v4-template Repository](https://github.com/uniswapfoundation/v4-template)
- **Findings**:
  - HookMiner はソルト値を反復探索し、目的のビットパターンを持つアドレスを発見
  - CREATE2 Deployer アドレス: `0x4e59b44847b379578588920ca78fbf26c0b4956c`
  - v4-template 内に `HookMiner.sol` ライブラリが提供されている
  - 探索は計算コストがかかるため、事前にオフチェーンで実行推奨
- **Implications**:
  - デプロイスクリプトに HookMiner 統合が必須
  - テスト環境では固定ソルト使用でテスト効率化可能

### Uniswap v4 テストネット デプロイ状況

- **Context**: 対象チェーン（Base Sepolia, World Chain Sepolia）での Uniswap v4 利用可能性を調査
- **Sources Consulted**:
  - [Uniswap v4 Deployments](https://docs.uniswap.org/contracts/v4/deployments)
  - World Chain 公式ドキュメント
- **Findings**:
  - **Base Sepolia**: PoolManager `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` ✅
  - **Arbitrum Sepolia**: PoolManager `0xFB3e0C6F74eB1a21CC1Da29aeC80D2Dfe6C9a317` ✅
  - **World Chain Sepolia**: 公式デプロイメント一覧に記載なし ⚠️
- **Implications**:
  - World Chain Sepolia は Uniswap v4 未対応の可能性
  - 代替案: Base Sepolia + Arbitrum Sepolia の2チェーン構成
  - または Base Sepolia 単独でのデモ構成

### 動的手数料実装パターン

- **Context**: L2稼働率に応じた手数料調整の実装方法を調査
- **Sources Consulted**:
  - [Dynamic Fees Concept](https://docs.uniswap.org/contracts/v4/concepts/dynamic-fees)
  - Umbrella Research - Uniswap v4 Hooks Guide
- **Findings**:
  - `beforeSwap` で手数料を返す際、`fee | OVERRIDE_FEE_FLAG` で上書き
  - 手数料は bps (basis points) で指定、100 = 0.01%, 3000 = 0.3%
  - 動的手数料は Pool 作成時に有効化する必要あり（後から変更不可）
  - Oracle 呼び出しはガスコスト考慮が必要
- **Implications**:
  - Pool 初期化時に `DYNAMIC_FEE_FLAG` を設定
  - 手数料計算はシンプルな段階式（ガス効率重視）
  - Oracle 呼び出しは1回/スワップに制限

### v4-core / v4-periphery 依存関係

- **Context**: Foundry プロジェクトへの依存関係導入方法を調査
- **Sources Consulted**:
  - [v4-core GitHub](https://github.com/Uniswap/v4-core)
  - [v4-periphery GitHub](https://github.com/Uniswap/v4-periphery)
- **Findings**:
  - v4-core: IPoolManager, Hooks, PoolKey, BalanceDelta 等の基本型
  - v4-periphery: BaseHook, StateLibrary, PositionManager 等のヘルパー
  - Solidity 0.8.24+ が必要（transient storage 対応）
  - forge install で導入可能
- **Implications**:
  - Solidity バージョンを 0.8.26 に統一（core-token-system と同期）
  - BaseHook を継承して UtilizationHook を実装
  - remappings.txt で v4-core, v4-periphery を設定

### Mock Oracle インターフェース（core-token-system 連携）

- **Context**: core-token-system が提供する Mock Oracle との統合方法を確認
- **Sources Consulted**:
  - `.kiro/specs/core-token-system/design.md`
- **Findings**:
  - `IMockOracle.getUtilization()` が稼働率（0-100%）を返す
  - `IMockOracle.setUtilization(uint256)` でデモ用に稼働率変更可能
  - 各L2チェーンに独立してデプロイされる
- **Implications**:
  - UtilizationHook は IMockOracle インターフェースに依存
  - コンストラクタで Oracle アドレスを受け取る設計
  - 異常値（>100）の場合はデフォルト手数料を適用

---

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| **BaseHook 継承** | v4-periphery の BaseHook を継承して Hook 実装 | 標準パターン、セキュリティ検証済み | v4-periphery への依存 | **採用** |
| 直接 IHooks 実装 | IHooks インターフェースを直接実装 | 依存関係が少ない | onlyPoolManager 等の実装が必要 | 非推奨 |
| Proxy Pattern | Hook を Proxy 経由でデプロイ | アップグレード可能 | アドレスパターン制約と競合 | 不適合 |

---

## Design Decisions

### Decision: `beforeSwap のみ実装`

- **Context**: Hook の実装範囲を決定する必要がある
- **Alternatives Considered**:
  1. beforeSwap のみ — 動的手数料制御に必要最小限
  2. beforeSwap + afterSwap — スワップ前後でロジック分割
  3. 全フック実装 — 完全な制御
- **Selected Approach**: beforeSwap のみ
- **Rationale**:
  - 動的手数料は beforeSwap で完結
  - afterSwap は本仕様では不要（ログはイベントで対応）
  - 最小限の実装でガスコスト削減
- **Trade-offs**:
  - ✅ シンプル、ガス効率、デバッグ容易
  - ❌ afterSwap での追加処理は不可
- **Follow-up**: 将来的に afterSwap が必要な場合は別 Hook を追加

### Decision: `段階式手数料計算`

- **Context**: 稼働率に応じた手数料計算ロジックを決定
- **Alternatives Considered**:
  1. 線形補間 — utilization × maxFee
  2. 段階式 — 閾値ベースで3段階
  3. 指数曲線 — 高稼働率で急上昇
- **Selected Approach**: 段階式（3段階）
- **Rationale**:
  - 計算がシンプルでガス効率が良い
  - 閾値が明確で挙動が予測しやすい
  - デモで視覚的に変化が分かりやすい
- **Trade-offs**:
  - ✅ ガス効率、予測可能性
  - ❌ 滑らかな遷移ではない
- **Follow-up**: 閾値と手数料値はテスト結果に基づき調整

### Decision: `Base Sepolia 単独優先`

- **Context**: World Chain Sepolia に Uniswap v4 がデプロイされていない可能性への対応
- **Alternatives Considered**:
  1. Base Sepolia + World Chain Sepolia — 要件通り
  2. Base Sepolia + Arbitrum Sepolia — 両方で v4 利用可能
  3. Base Sepolia 単独 — 最小構成でデモ
- **Selected Approach**: Base Sepolia 優先、Arbitrum Sepolia を代替として準備
- **Rationale**:
  - Base Sepolia は PoolManager 確認済み
  - World Chain Sepolia は事前検証が必要
  - デモ成功を優先し、確実なチェーンを使用
- **Trade-offs**:
  - ✅ 確実なデプロイ
  - ❌ 当初の2チェーン構成から変更の可能性
- **Follow-up**: World Chain Sepolia での v4 利用可能性を実装フェーズで再確認

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| HookMiner ソルト探索失敗 | 高 | 探索範囲拡大（最大 1M iterations）、事前テスト |
| v4-core/v4-periphery バージョン互換性 | 中 | v4-template の動作確認済みバージョンを使用 |
| World Chain Sepolia 非対応 | 中 | Arbitrum Sepolia を代替として準備 |
| Oracle 呼び出しガス超過 | 低 | 単純な storage 読み取りのみ、ベンチマーク実施 |
| Pool 初期化失敗 | 中 | PositionManager 経由の標準フロー使用 |

---

## References

- [Uniswap v4 Documentation](https://docs.uniswap.org/contracts/v4/) — 公式ドキュメント
- [v4-template Repository](https://github.com/uniswapfoundation/v4-template) — 公式テンプレート
- [Uniswap v4 Deployments](https://docs.uniswap.org/contracts/v4/deployments) — デプロイアドレス一覧
- [IHooks Interface](https://github.com/Uniswap/v4-core/blob/main/src/interfaces/IHooks.sol) — Hook インターフェース定義
- [BaseHook](https://github.com/Uniswap/v4-periphery/blob/main/src/utils/BaseHook.sol) — Hook 基底クラス
- [HookMiner](https://github.com/uniswapfoundation/v4-template/blob/main/test/utils/HookMiner.sol) — アドレスマイニングユーティリティ
