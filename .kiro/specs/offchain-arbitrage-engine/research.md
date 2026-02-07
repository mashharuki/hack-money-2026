# Research & Design Decisions: Offchain Arbitrage Engine

---
**Purpose**: ディスカバリーフェーズの調査結果と、design.md に反映されたアーキテクチャ判断の根拠を記録する。
---

## Summary

- **Feature**: offchain-arbitrage-engine
- **Discovery Scope**: New Feature / Complex Integration
- **Key Findings**:
  1. Uniswap v4 価格読み取りは StateView コントラクト経由で `getSlot0(poolId)` を使用（PoolManager 直接呼び出しではない）
  2. Yellow SDK (`@erc7824/nitrolite`) は WebSocket + EIP-712 認証ベースで、Node.js 完全対応。セッション管理 API あり
  3. WorldCoin Sepolia には Uniswap v4 Hook/Pool 未デプロイのため、チェーンペアを Base Sepolia + Unichain Sepolia に変更推奨

---

## Research Log

### Uniswap v4 オフチェーン価格読み取り

- **Context**: Price Watcher が各チェーンの CPT/USDC Pool 価格を取得する方法の調査
- **Sources Consulted**:
  - [Uniswap v4 StateView ガイド](https://docs.uniswap.org/contracts/v4/guides/state-view)
  - [Uniswap v4 Pool State 読み取り](https://docs.uniswap.org/contracts/v4/guides/read-pool-state)
  - [Uniswap v4 Deployments](https://docs.uniswap.org/contracts/v4/deployments)
  - [sqrtPriceX96 解説 (RareSkills)](https://rareskills.io/post/uniswap-v3-sqrtpricex96)
- **Findings**:
  - **StateView** コントラクト（`v4-periphery` の `lens/StateView.sol`）がオフチェーン読み取り用の推奨手段
  - Base Sepolia StateView アドレス: `0x571291b572ed32ce6751a2cb2486ebee8defb9b4`
  - `getSlot0(bytes32 poolId)` は `(sqrtPriceX96, tick, protocolFee, lpFee)` を返す view 関数
  - StateLibrary はオンチェーンコントラクト内部用。オフチェーンからは StateView を使う
  - `getLiquidity(poolId)` で流動性も取得可能
- **Implications**:
  - 各チェーンの StateView アドレスを config に追加する必要あり
  - ABI は最小限（getSlot0 + getLiquidity）で済む
  - gas-free の view 呼び出しなので、5秒ポーリングに適している

### sqrtPriceX96 → 価格変換

- **Context**: sqrtPriceX96 形式から人間可読な価格への変換方法
- **Sources Consulted**:
  - [Uniswap v3 Math Primer](https://blog.uniswap.org/uniswap-v3-math-primer)
  - コントラクトの `InitializePool.s.sol` 内の計算ロジック
- **Findings**:
  - 公式: `price = (sqrtPriceX96 / 2^96)^2 * 10^(decimals0 - decimals1)`
  - token0 は常にアドレスが小さい方（`address(CPT) < address(USDC)` の比較で決定）
  - price は token1/token0 の比率を返す
  - BigInt 演算で精度を保つ実装が必要（Number への変換は精度損失のリスク）
- **Implications**:
  - Pool ごとに token0/token1 のアドレス順序を把握する必要がある
  - price が「USDC per CPT」か「CPT per USDC」かはトークン順序に依存
  - 高精度 BigInt 実装を types.ts 内のユーティリティ関数として提供

### Yellow SDK (Nitrolite) API 調査

- **Context**: Yellow SDK を使ったガスレスオフチェーン取引セッションの実装可能性調査
- **Sources Consulted**:
  - [npmjs.com/@erc7824/nitrolite](https://www.npmjs.com/package/@erc7824/nitrolite)
  - [GitHub erc7824/nitrolite](https://github.com/erc7824/nitrolite)
  - [Yellow Network Quick Start](https://docs.yellow.org/docs/build/quick-start/)
  - プロジェクト内 `.claude/skills/yellow-protocol/SKILL.md`
  - プロジェクト内 `.claude/skills/yellow-protocol/references/quickstart.md`
- **Findings**:
  - **パッケージ**: `@erc7824/nitrolite`（npm で利用可能）
  - **ClearNode URL**: `wss://clearnet.yellow.com/ws`
  - **Node.js 対応**: 完全対応（`ws` パッケージ使用）
  - **主要エクスポート**:
    - 認証: `createAuthRequestMessage`, `createAuthVerifyMessage`, `createEIP712AuthMessageSigner`
    - セッション: `createAppSessionMessage`, `createCloseAppSessionMessage`
    - ユーティリティ: `parseRPCResponse`, `generateRequestId`, `RPCMethod`
  - **認証フロー**: auth_request → auth_challenge → EIP-712 署名 → auth_verify → JWT 取得
  - **セッションフロー**: create_app_session → off-chain 操作 → close_app_session
  - **署名注意点**: `wallet.signMessage()` は使わない（EIP-191 プレフィックスが付く）。非認証メッセージは raw digest を署名
- **Implications**:
  - 実装は可能だが、認証フロー・セッション管理の複雑性が高い
  - モックファースト戦略で確実にデモを動かし、実 SDK 統合はストレッチゴール
  - `IYellowSession` インターフェースで抽象化し、Mock/Real を DI 切り替え

### WorldCoin Sepolia Uniswap v4 可用性

- **Context**: 要件で指定された L2-B (WorldCoin Sepolia) での Uniswap v4 Pool 利用可能性
- **Sources Consulted**:
  - `contract/deployed-addresses.json`（プロジェクト内）
  - `contract/uniswap-v4-addresses.json`（プロジェクト内）
  - [Uniswap v4 Deployments](https://docs.uniswap.org/contracts/v4/deployments)
- **Findings**:
  - WorldCoin Sepolia には CPT + MockOracle のみデプロイ済み
  - Hook, Pool ID, PoolManager は未デプロイ / アドレス不明
  - Uniswap v4 公式デプロイ一覧に WorldCoin Sepolia は含まれていない
  - Base Sepolia と Unichain Sepolia は PoolManager + Hook + Pool がフルデプロイ済み
- **Implications**:
  - **設計判断**: チェーンペアを Base Sepolia (L2-A) + Unichain Sepolia (L2-B) に変更
  - WorldCoin Sepolia は将来対応として config で拡張可能にしておく
  - 要件の「WorldCoin Sepolia」は config レベルで差し替え可能な設計にする

### コントラクト ABI 調査

- **Context**: オフチェーンスクリプトが参照するコントラクトの ABI 確認
- **Sources Consulted**:
  - `contract/src/hooks/UtilizationHook.sol`
  - `contract/src/MockOracle.sol`
  - `contract/src/ComputeToken.sol`
  - `contract/test/PoolHookIntegration.t.sol`
- **Findings**:
  - **UtilizationHook**: `calculateDynamicFee(uint256)` で手数料計算。閾値: LOW(30%), HIGH(70%)。イベント: `FeeOverridden(poolId, utilization, fee)`
  - **MockOracle**: `getUtilization() view returns (uint256)`, `setUtilization(uint256)`, イベント: `UtilizationUpdated(uint256)`
  - **ComputeToken**: 標準 ERC20 + `mint(uint256)` (onlyOwner)。18 decimals
  - **Pool 構造**: `LPFeeLibrary.DYNAMIC_FEE_FLAG`, tickSpacing=60, token 順序はアドレス比較で決定
  - **Swap イベント**: `Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)` で sqrtPriceX96 含む
- **Implications**:
  - Price Watcher は StateView (getSlot0) + ERC20 (balanceOf) の最小 ABI セットで十分
  - MockOracle の getUtilization は補助情報として読み取り可能（ダッシュボード連携用）
  - ABI は scripts/arbitrage/abi/ にミニマルなものをコピーして使用

---

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Event-driven Pipeline | EventEmitter で Watcher → Engine → Yellow を接続 | 疎結合、各コンポーネント独立テスト可能、非同期フロー自然 | EventEmitter のエラー伝播が暗黙的 | Node.js ネイティブ EventEmitter で十分 |
| Callback Chain | 直接的な関数コールバック | シンプル、デバッグしやすい | コンポーネント間結合度が高い | ハッカソンには十分だが拡張性低い |
| Message Queue | Redis/NATS 等の外部 MQ | スケーラブル、永続化可能 | 外部依存、ハッカソンには過剰 | 対象外 |

**選択**: Event-driven Pipeline（EventEmitter ベース）

---

## Design Decisions

### Decision: チェーンペアの変更

- **Context**: 要件では Base Sepolia + WorldCoin Sepolia だが、WorldCoin Sepolia に Uniswap v4 未デプロイ
- **Alternatives Considered**:
  1. WorldCoin Sepolia に Hook/Pool をデプロイ — PoolManager が存在しないため困難
  2. Base Sepolia + Unichain Sepolia に変更 — 両方フルデプロイ済み
  3. モック価格フィードで WorldCoin Sepolia 対応 — デモとしては弱い
- **Selected Approach**: Base Sepolia (L2-A) + Unichain Sepolia (L2-B)。config.ts で差し替え可能
- **Rationale**: 両チェーンとも Hook + Pool + PoolManager がデプロイ済みで、即座にリアルな価格差を取得可能
- **Trade-offs**: 要件文書との乖離（ただし config 変更で対応可能）
- **Follow-up**: 要件の「WorldCoin Sepolia」参照を更新、または config で抽象化

### Decision: StateView による価格読み取り

- **Context**: Uniswap v4 PoolManager からの価格取得方法
- **Alternatives Considered**:
  1. PoolManager.extsload() — 低レベル、ABI が複雑
  2. StateView.getSlot0() — 推奨の view 関数
  3. Swap イベント監視 — リアルタイムだがスワップが発生しないと更新されない
- **Selected Approach**: StateView.getSlot0() をポーリング
- **Rationale**: 公式推奨のオフチェーン読み取り手段。gas-free view 呼び出し。ABI がシンプル
- **Trade-offs**: ポーリング（5秒）のため最大5秒の遅延。イベント駆動よりリアルタイム性は劣る
- **Follow-up**: 各チェーンの StateView アドレスを確認・設定に追加

### Decision: インターフェースベースの Yellow Session DI

- **Context**: Yellow SDK 統合の不確実性をモックで緩和
- **Alternatives Considered**:
  1. Yellow SDK 直接使用のみ — 統合失敗リスク
  2. モック実装のみ — デモとして弱い
  3. インターフェース + DI — Mock/Real を環境変数で切り替え
- **Selected Approach**: `IYellowSession` インターフェースで抽象化。`USE_YELLOW_MOCK` 環境変数で切り替え
- **Rationale**: モックファーストで確実にデモを動作させ、Yellow SDK 統合は時間があれば追加
- **Trade-offs**: インターフェース設計の初期コスト。ただし長期的なメリットが大きい
- **Follow-up**: Yellow SDK 実統合時に `RealYellowSession` クラスを実装

### Decision: EventEmitter による コンポーネント間通信

- **Context**: Watcher → Engine → Yellow のパイプライン設計
- **Alternatives Considered**:
  1. 直接コールバック — シンプルだが結合度高い
  2. Node.js EventEmitter — 疎結合、既存パターンに合致
  3. RxJS Observable — 高機能だが追加依存
- **Selected Approach**: Node.js 標準の `EventEmitter`
- **Rationale**: 外部依存なし、TypeScript 型安全な EventEmitter パターンで十分
- **Trade-offs**: エラー伝播に注意が必要（`error` イベントの適切なハンドリング）
- **Follow-up**: 型付き EventEmitter ラッパーを types.ts で定義

---

## Risks & Mitigations

- **Yellow SDK 統合失敗** — MockYellowSession フォールバック実装で緩和。`USE_YELLOW_MOCK=true` がデフォルト
- **StateView アドレス不正** — 各チェーンで `getSlot0` の疎通確認を実装前に実施
- **sqrtPriceX96 精度問題** — BigInt 演算で精度を保持。Number 変換は最終表示時のみ
- **RPC レート制限** — 5秒ポーリング間隔は一般的な公開 RPC の制限内。バックオフロジックも実装
- **WebSocket 接続不安定 (Yellow SDK)** — 再接続ロジック + 指数バックオフを実装

---

## References

- [Uniswap v4 StateView Guide](https://docs.uniswap.org/contracts/v4/guides/state-view)
- [Uniswap v4 Read Pool State](https://docs.uniswap.org/contracts/v4/guides/read-pool-state)
- [Uniswap v4 Deployments](https://docs.uniswap.org/contracts/v4/deployments)
- [sqrtPriceX96 Explained (RareSkills)](https://rareskills.io/post/uniswap-v3-sqrtpricex96)
- [@erc7824/nitrolite (npm)](https://www.npmjs.com/package/@erc7824/nitrolite)
- [Yellow Network Quick Start](https://docs.yellow.org/docs/build/quick-start/)
- [ERC7824 State Channels](https://erc7824.org/)
- [viem Documentation](https://viem.sh/)
