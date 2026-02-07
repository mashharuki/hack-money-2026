# Research & Design Decisions: l2-utilization-oracle

---
**Purpose**: ディスカバリーフェーズの調査結果、アーキテクチャ検討、設計判断の根拠を記録する。
---

## Summary
- **Feature**: `l2-utilization-oracle`
- **Discovery Scope**: Complex Integration（既存コントラクト拡張 + 外部依存統合）
- **Key Findings**:
  - Chainlink Functions は Base Sepolia でサポート済み（Router: `0xf9B8fc0781971Add66D33369043c185880232f53`）。Unichain Sepolia は未サポート
  - FunctionsClient は別コントラクト（FunctionsReceiver）として分離が最適。Oracle 本体の責務肥大化を回避
  - Hook は `IMockOracle` を immutable で保持しているため、新インターフェース利用には再デプロイが必要（テストネットのため許容）

## Research Log

### Chainlink Functions ネットワーク対応状況
- **Context**: 要件 7（Chainlink Functions 検証）の実現可能性確認
- **Sources Consulted**: Chainlink 公式ドキュメント、プロジェクト内 SKILL.md (`chainlink-functions-dev`)
- **Findings**:
  - Base Sepolia: サポート済み。Router `0xf9B8fc0781971Add66D33369043c185880232f53`、DON ID `fun-base-sepolia-1`
  - Ethereum Sepolia: サポート済み。Router `0xb83E47C2bC239B3bf370bc41e1459A34b41238D0`
  - Unichain Sepolia: **未サポート**
  - JavaScript ソースの制約: 実行時間 10秒以内、コード 4KB以下、レスポンス 256 bytes以下
- **Implications**: Functions 検証は Base Sepolia のみで実装。Unichain Sepolia は bot 更新のみで運用。設定管理で chain ごとの Functions 有効/無効を切り替え可能にする

### FunctionsClient 統合パターン
- **Context**: Oracle が FunctionsClient を直接継承するか、分離するかの設計判断
- **Sources Consulted**: Chainlink Functions ドキュメント、FunctionsConsumer.sol サンプル
- **Findings**:
  - `FunctionsClient` 継承にはコンストラクタで Router アドレスが必要
  - `fulfillRequest(bytes32, bytes, bytes)` を override して結果を受信
  - `_sendRequest(bytes, uint64, uint32, bytes32)` でリクエスト送信
  - Forge パッケージ: `smartcontractkit/chainlink-evm`、remapping: `@chainlink/contracts/=lib/chainlink-evm/contracts/`
- **Implications**: Oracle 本体に FunctionsClient を統合すると責務が過大になる。FunctionsReceiver を分離し、Oracle の authorized updater として登録するパターンを採用

### Chainlink Automation による定期実行
- **Context**: Functions を15分間隔で自動トリガーする方法
- **Sources Consulted**: Chainlink Automation ドキュメント
- **Findings**:
  - Time-based upkeep を使用可能。CRON 式: `0 */15 * * * *`
  - `AutomationCompatibleInterface` を実装し、`performUpkeep()` で Functions リクエストを発行
  - Automation と Functions で別々の Subscription（LINK）が必要
  - Automation の forwarder アドレスのみが `performUpkeep` を呼べる
- **Implications**: FunctionsReceiver が `AutomationCompatibleInterface` も実装する設計が最もシンプル

### Hook 再デプロイの必要性
- **Context**: IMockOracle 拡張時の Hook への影響
- **Sources Consulted**: 既存コード（UtilizationHook.sol）
- **Findings**:
  - Hook は `IMockOracle public immutable oracle` を保持
  - `getUtilizationWithMeta()` を呼ぶには新インターフェース型が必要
  - Solidity の immutable 変数はデプロイ後変更不可
  - テストネットのため再デプロイのコストは低い
- **Implications**: Hook を新インターフェース（`IMockOracle` 拡張）で再デプロイ。CREATE2 + HookMiner による再マイニングが必要

### EMA 計算のオンチェーン vs オフチェーン
- **Context**: EMA 計算をどこで実行するか
- **Sources Consulted**: Solidity の固定小数点演算制約
- **Findings**:
  - Solidity では浮動小数点がないため、EMA のα計算にスケーリングが必要
  - オフチェーン（TypeScript/JavaScript）では標準の浮動小数点演算が使用可能
  - オンチェーンでは結果（0-100 整数）のみを保存し、計算はオフチェーンで実行するのが効率的
- **Implications**: EMA 計算は bot（TypeScript）と Chainlink Functions（JavaScript）の両方でオフチェーン実行。Oracle コントラクトは計算済みの値を受け取るのみ

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Oracle 直接継承 | MockOracle が FunctionsClient を継承 | ファイル数最小 | 責務過大、Chainlink 依存がコア契約に侵入 | 却下 |
| FunctionsReceiver 分離 | 別コントラクトが FunctionsClient を継承し、Oracle の updater として登録 | 責務分離、テスタビリティ向上 | ファイル数増加 | **採用** |
| Proxy パターン | Oracle をプロキシ化して差し替え可能に | アップグレード容易 | 過剰設計、ハッカソン向きではない | 却下 |

## Design Decisions

### Decision: FunctionsReceiver の分離
- **Context**: Chainlink Functions の応答をどのコントラクトで受信するか
- **Alternatives Considered**:
  1. MockOracle が FunctionsClient を直接継承
  2. 別コントラクト FunctionsReceiver が受信し Oracle に書き込み
- **Selected Approach**: Option 2（FunctionsReceiver 分離）
- **Rationale**: Oracle のコア責務（データ保存・stale 判定・allowlist）と Chainlink 固有のロジック（リクエスト送信・応答デコード）を分離することで、テストが容易になり、Chainlink 非対応チェーンでも Oracle 単体が動作する
- **Trade-offs**: ファイル数 +1、デプロイステップ +1。ただし責務の明確性が大幅に向上
- **Follow-up**: FunctionsReceiver を Oracle の authorized updater に登録する手順をデプロイスクリプトに含める

### Decision: Hook 再デプロイ
- **Context**: 新インターフェース `getUtilizationWithMeta()` を Hook から呼ぶために再デプロイが必要
- **Alternatives Considered**:
  1. Hook 内で低レベル call を使用（型安全性を犠牲に）
  2. Hook を新インターフェース型で再デプロイ
- **Selected Approach**: Option 2（再デプロイ）
- **Rationale**: テストネット環境のため再デプロイコストは低い。型安全性と可読性を優先
- **Trade-offs**: Pool 再作成が必要。既存のデプロイスクリプト（DeployHook.s.sol）を修正して対応
- **Follow-up**: 再デプロイ手順を tasks に含める

### Decision: Unichain Sepolia での Functions 非対応
- **Context**: Chainlink Functions は Unichain Sepolia をサポートしていない
- **Alternatives Considered**:
  1. Unichain 上でも Functions を試みる（不可能）
  2. Unichain は bot 更新のみで運用
  3. Unichain を対象外にする
- **Selected Approach**: Option 2（bot のみ）
- **Rationale**: bot 更新 + TTL/stale 検出だけでも安全性は確保される。ハッカソンデモでは Base Sepolia で Functions 検証を見せ、アーキテクチャの柔軟性を示す
- **Trade-offs**: Unichain では二重検証が不可。ただし stale TTL による安全策で最低限の保護は維持
- **Follow-up**: 設定管理で chain ごとに Functions 有効/無効をフラグ管理

## Risks & Mitigations
- Chainlink Functions の Base Sepolia 可用性が一時的に低下するリスク → stale TTL + DEFAULT_FEE で安全側にフォールバック
- LINK トークンの枯渇リスク → Subscription 残高監視を bot に組み込む
- RPC レート制限 → 主副 RPC のフォールバック + リクエスト間隔の調整
- Hook 再デプロイ時の Pool 移行 → デプロイスクリプトを更新し、新 Pool 作成を自動化

## References
- [Chainlink Functions Documentation](https://docs.chain.link/chainlink-functions) — Functions の公式ガイド
- [Chainlink Automation Time-Based Upkeep](https://docs.chain.link/chainlink-functions/tutorials/automate-functions) — 定期実行パターン
- [Chainlink Functions Subscription Manager](https://functions.chain.link/) — Subscription 管理UI
- プロジェクト内: `.claude/skills/chainlink-functions-dev/SKILL.md` — Chainlink Functions 開発ガイド
- プロジェクト内: `.claude/skills/defi-development/references/oracle-guide.md` — オラクル設計パターン
