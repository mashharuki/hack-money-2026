# Project Structure

## Organization Philosophy

**機能ドメイン優先**: オンチェーン・オフチェーン・フロントエンドを明確に分離し、各層の責務を明確化する。

## Directory Patterns

### Smart Contracts (`/contracts/`)
**Purpose**: Solidity コントラクト（CPT Token, Operator Vault, Uniswap v4 Hook）
**Pattern**:
- `/contracts/tokens/` - ERC20 CPT Token
- `/contracts/vault/` - Operator Vault (USDC 収益管理)
- `/contracts/hooks/` - Uniswap v4 Hook (動的手数料制御)
- `/contracts/test/` - テスト用コントラクト (Mock Oracle 等)

**Example**:
```
/contracts/tokens/ComputeToken.sol
/contracts/hooks/UtilizationHook.sol
/contracts/vault/OperatorVault.sol
```

### Offchain Engine (`/offchain/`)
**Purpose**: 価格監視・裁定エンジン・Yellow セッション実行・決済オーケストレーション
**Pattern**:
- `/offchain/watcher/` - 価格差検知 (Uniswap v4 プール監視)
- `/offchain/arbitrage/` - Ghost Arbitrage Engine (戦略生成・実行指示)
- `/offchain/yellow/` - Yellow SDK 統合・セッション管理
- `/offchain/settlement/` - Arc + Circle での USDC 決済処理

**Example**:
```typescript
// /offchain/watcher/price-watcher.ts
import { watchPools } from './pool-monitor'
```

### Frontend (`/frontend/` or `/app/`)
**Purpose**: Next.js ダッシュボード (価格差・Hook状態・セッションログ・Vault残高可視化)
**Pattern**:
- `/app/` - Next.js App Router
- `/components/` - UI コンポーネント (Shadcn/ui ベース)
- `/lib/` - ユーティリティ・設定・型定義

**Example**:
```typescript
// /app/dashboard/page.tsx
// /components/price-chart.tsx
// /lib/viem-client.ts
```

### Scripts (`/scripts/`)
**Purpose**: デプロイ・初期化・デモ実行用スクリプト
**Example**:
```typescript
// /scripts/deploy-all.ts
// /scripts/demo-arbitrage.ts
```

### Configuration (`/`)
**Purpose**: プロジェクト全体の設定ファイル（ルート直下）
- `foundry.toml` or `hardhat.config.ts` - コントラクト設定
- `tsconfig.json` - TypeScript 設定
- `package.json` - 依存関係・スクリプト

## Naming Conventions

- **Files**: kebab-case (`price-watcher.ts`, `operator-vault.sol`)
- **Contracts**: PascalCase (`ComputeToken.sol`, `UtilizationHook.sol`)
- **Components**: PascalCase (`PriceChart.tsx`, `VaultBalance.tsx`)
- **Functions**: camelCase (`watchPools()`, `executeArbitrage()`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_SPREAD`, `ARBITRAGE_THRESHOLD`)

## Import Organization

```typescript
// 1. External libraries
import { createPublicClient } from 'viem'
import { mainnet } from 'viem/chains'

// 2. Internal modules (絶対パス推奨)
import { watchPools } from '@/offchain/watcher'
import { executeArbitrage } from '@/offchain/arbitrage'

// 3. Types
import type { PriceData } from '@/types'

// 4. Relative imports (同一ディレクトリ内のみ)
import { formatPrice } from './utils'
```

**Path Aliases** (tsconfig.json):
- `@/`: プロジェクトルート
- `@/contracts`: コントラクトルート
- `@/offchain`: オフチェーンエンジンルート

## Code Organization Principles

### 責務の分離
- **オンチェーン**: 価格形成・決済・状態管理のみ
- **オフチェーン**: 価格監視・戦略・実行ロジック
- **フロントエンド**: 可視化のみ（ビジネスロジックを含まない）

### 依存方向
- フロントエンド → オフチェーン (読み取り専用)
- オフチェーン → オンチェーン (コントラクト呼び出し)
- コントラクト間は最小限の依存（CPT Token ← Vault, Hook は Pool 参照のみ）

### ハッカソンスコープでの簡略化
- **Indexer**: 軽量な自前実装（必要最小限のイベントログ保持）
- **Oracle**: モック実装可（L2稼働率シグナル）
- **Multi-chain**: L2-A (Unichain), L2-B (Linea) の2チェーンに限定

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
