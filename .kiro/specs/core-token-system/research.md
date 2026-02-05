# Research & Design Decisions: Core Token System

---
**Purpose**: Discovery findings と設計判断の根拠を記録します。

**Usage**:
- Discovery Phase で調査した外部依存関係、技術選択、設計トレードオフを記録
- 設計判断の根拠とリスクを文書化
- 将来の監査・再利用のためのリファレンスを提供

---

## Summary
- **Feature**: `core-token-system`
- **Discovery Scope**: Extension (既存Foundryプロジェクトへのコントラクト追加)
- **Key Findings**:
  - OpenZeppelin Contractsの導入が必要（ERC20, Ownable, ReentrancyGuard）
  - Base Sepolia, WorldCoin Sepolia, Arc の3チェーンへのマルチチェーンデプロイが必要
  - USDC Testnet アドレスを確認済み（Base Sepolia, Arc Testnet）
  - Worldcoin Sepolia は World Chain Sepolia として運用中、USDC は CCTP 経由で取得可能

## Research Log

### USDC Testnet Contract Addresses

**Context**: Operator Vault コントラクトが USDC を管理するため、各チェーンの USDC アドレスが必要

**Sources Consulted**:
- [Base Sepolia USDC on BaseScan](https://sepolia.basescan.org/token/0x036cbd53842c5426634e7929541ec2318f3dcf7e)
- [Arc Contract Addresses Documentation](https://docs.arc.network/arc/references/contract-addresses)
- [World Chain Testnet Documentation](https://docs.world.org/world-chain/quick-start/info)
- [Circle USDC Contract Addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses)

**Findings**:

#### Base Sepolia
- **USDC Contract**: `0x036CbD53842c5426634e7929541eC2318f3dCF7E`
- **Source**: BaseScan Sepolia, Circle公式ドキュメント
- **Status**: 公式 USDC Testnet、FiatTokenProxy 実装
- **Faucet**: Circle Testnet Faucet または ETHGlobal Faucet

#### Arc Testnet
- **USDC Contract**: `0x3600000000000000000000000000000000000000`
- **Source**: Arc公式ドキュメント
- **Status**: Native EVM asset（ガストークン）、ERC20インターフェースも提供
- **重要**: Native USDC (18 decimals) と ERC-20 USDC (6 decimals) が混在
- **推奨**: ERC-20 インターフェース（6 decimals）を Operator Vault で使用

#### World Chain Sepolia (WorldCoin Sepolia)
- **Network**: World Chain Sepolia (OP Stack L2)
- **USDC取得方法**: CCTP (Cross-Chain Transfer Protocol) 経由で Ethereum Sepolia から転送
- **Status**: World Chain は Worldcoin の新しいネットワーク名、Sepolia testnet として稼働
- **Faucet**: [World Chain Testnet Faucet](https://www.l2faucet.com/world), [Alchemy Faucet](https://www.alchemy.com/faucets/world-chain-sepolia)
- **注意**: 直接的な USDC コントラクトアドレスは未確認、CCTP を使用してブリッジする必要あり

**Implications**:
- Base Sepolia と Arc Testnet の USDC アドレスは確定
- World Chain Sepolia では、USDC を CCTP 経由でブリッジする必要があるため、デモ実行前の準備が必要
- Arc の USDC は ERC-20 インターフェース（6 decimals）を使用する必要がある

### OpenZeppelin Contracts Integration

**Context**: CPT Token (ERC20), Operator Vault (Ownable, ReentrancyGuard) の実装に必要

**Sources Consulted**:
- [OpenZeppelin Contracts Documentation](https://docs.openzeppelin.com/contracts/5.x/)
- [Foundry Book - Dependencies](https://book.getfoundry.sh/projects/dependencies)

**Findings**:
- OpenZeppelin Contracts は Foundry で `forge install` により導入可能
- 推奨バージョン: v5.x（Solidity 0.8.20+対応）
- 必要なコンポーネント:
  - `@openzeppelin/contracts/token/ERC20/ERC20.sol`
  - `@openzeppelin/contracts/access/Ownable.sol`
  - `@openzeppelin/contracts/utils/ReentrancyGuard.sol`

**Installation Command**:
```bash
cd contract
forge install OpenZeppelin/openzeppelin-contracts
```

**Implications**:
- 標準的な ERC20 実装を活用可能
- セキュリティベストプラクティスが組み込み済み
- 監査済みのライブラリを使用することでリスク低減

### Foundry Multi-Chain Deployment Pattern

**Context**: 3チェーン（Base Sepolia, World Chain Sepolia, Arc）へのデプロイ自動化

**Sources Consulted**:
- [Foundry Book - Deploying](https://book.getfoundry.sh/forge/deploying)
- [Foundry Book - Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting)

**Findings**:
- Foundry スクリプトは `--rpc-url` オプションでチェーン切り替え可能
- 環境変数で RPC URL と Private Key を管理
- `vm.broadcast()` でトランザクション実行
- デプロイ結果は `forge script --json` で JSON 出力可能

**Implementation Pattern**:
```solidity
contract DeployCore is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        CPTToken cpt = new CPTToken("Compute Token", "CPT");
        MockOracle oracle = new MockOracle();
        OperatorVault vault = new OperatorVault(usdcAddress);

        vm.stopBroadcast();

        // Log addresses
        console.log("CPT Token:", address(cpt));
        console.log("Mock Oracle:", address(oracle));
        console.log("Operator Vault:", address(vault));
    }
}
```

**Implications**:
- 環境変数ベースの柔軟なデプロイが可能
- JSON 出力により、デプロイ結果を自動的に記録可能
- 各チェーンごとに異なる USDC アドレスを指定可能

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| **Monolithic Contract** | すべての機能を単一コントラクトに実装 | シンプル、ガスコスト低 | 責任範囲不明確、テスト困難、拡張性低 | ❌ 非推奨 |
| **Domain-Separated Contracts** | CPT Token, Mock Oracle, Operator Vault を独立したコントラクトとして実装 | 責任分離明確、テスト容易、拡張性高 | デプロイコスト増、複数コントラクト管理 | ✅ 推奨（Option B） |
| **Proxy Pattern** | Upgradeable Proxy パターンを使用 | アップグレード可能 | 複雑性増、ガスコスト増、監査コスト増 | ⚠️ ハッカソンスコープでは不要 |

## Design Decisions

### Decision: Domain-Separated Contracts

**Context**: CPT Token, Mock Oracle, Operator Vault の3つのコンポーネントを単一コントラクトにするか、分離するか

**Alternatives Considered**:
1. **Monolithic Contract** - すべてを単一コントラクトに実装
2. **Domain-Separated Contracts** - 各ドメインを独立したコントラクトとして実装
3. **Proxy Pattern** - Upgradeable Proxy パターンを使用

**Selected Approach**: Domain-Separated Contracts

**Rationale**:
- **責任分離**: 各コントラクトが明確な責任を持つ（Single Responsibility Principle）
- **テスト容易性**: 各コントラクトを独立してテスト可能
- **拡張性**: 他の仕様（uniswap-v4-integration, settlement-layer）が依存する際に明確な境界が存在
- **ハッカソンスコープ**: Proxy Pattern は複雑性が高く、アップグレード機能は不要

**Trade-offs**:
- ✅ 明確な責任分離、テスト容易性、拡張性
- ✅ OpenZeppelin活用で標準実装、セキュリティベストプラクティス準拠
- ❌ デプロイコスト増（3コントラクト分）- ハッカソンスコープでは許容範囲

**Follow-up**: デプロイスクリプトで3コントラクトを順次デプロイし、アドレスをJSON出力

---

### Decision: OpenZeppelin Contracts Usage

**Context**: ERC20, Ownable, ReentrancyGuard の実装方法

**Alternatives Considered**:
1. **OpenZeppelin Contracts** - 標準ライブラリを使用
2. **Custom Implementation** - 独自実装
3. **Solmate** - より軽量なライブラリを使用

**Selected Approach**: OpenZeppelin Contracts v5.x

**Rationale**:
- **標準実装**: ERC20, Ownable, ReentrancyGuard は OpenZeppelin が業界標準
- **監査済み**: OpenZeppelin は監査済みで、セキュリティベストプラクティスが組み込み済み
- **コミュニティサポート**: 広く使用されており、ドキュメント・コミュニティサポートが充実
- **Solidity 0.8.x対応**: v5.x は Solidity 0.8.20+ に対応

**Trade-offs**:
- ✅ セキュリティ、標準実装、監査済み、コミュニティサポート
- ❌ Solmate と比較してガスコストがやや高い - ハッカソンスコープでは許容範囲

**Follow-up**: `forge install OpenZeppelin/openzeppelin-contracts` で導入

---

### Decision: Arc USDC Interface (ERC-20, 6 decimals)

**Context**: Arc の USDC は Native USDC (18 decimals) と ERC-20 USDC (6 decimals) が混在

**Alternatives Considered**:
1. **Native USDC (18 decimals)** - ガストークンとしての USDC
2. **ERC-20 USDC (6 decimals)** - ERC-20 インターフェース

**Selected Approach**: ERC-20 USDC (6 decimals)

**Rationale**:
- **標準インターフェース**: ERC-20 インターフェースにより、他のチェーンと同じ IERC20 を使用可能
- **Decimal統一**: Base Sepolia USDC (6 decimals) と統一
- **Operator Vault実装簡略化**: IERC20 インターフェースのみで実装可能

**Trade-offs**:
- ✅ 標準インターフェース、Decimal統一、実装簡略化
- ⚠️ Native USDC (18 decimals) との混在に注意が必要（ドキュメント化）

**Follow-up**: デプロイスクリプトで Arc USDC アドレス (`0x3600000000000000000000000000000000000000`) を指定

---

### Decision: World Chain Sepolia USDC Bridging

**Context**: World Chain Sepolia では直接的な USDC コントラクトアドレスが未確認

**Alternatives Considered**:
1. **CCTP Bridging** - Ethereum Sepolia から USDC をブリッジ
2. **World Chain Faucet** - World Chain Testnet Faucet で USDC を取得
3. **Mock USDC** - World Chain Sepolia 専用の Mock USDC を作成

**Selected Approach**: CCTP Bridging（デモ準備時）

**Rationale**:
- **公式手法**: Circle の CCTP は公式のクロスチェーン転送プロトコル
- **実運用想定**: 本番環境でも CCTP を使用する可能性が高い
- **テスト環境整合性**: Ethereum Sepolia の USDC をブリッジすることで、実環境に近いテスト

**Trade-offs**:
- ✅ 公式手法、実運用想定、テスト環境整合性
- ❌ デモ準備に追加ステップが必要（CCTP ブリッジ実行）

**Follow-up**: デモスクリプト実装時に CCTP ブリッジ手順をドキュメント化

---

## Risks & Mitigations

### Risk 1: World Chain Sepolia USDC Bridging Complexity
- **Mitigation**: デモ準備時に CCTP ブリッジ手順をドキュメント化、自動化スクリプト作成

### Risk 2: Arc USDC Decimal Mismatch (18 decimals vs 6 decimals)
- **Mitigation**: ERC-20 インターフェース (6 decimals) を使用、ドキュメントに注意事項を記載

### Risk 3: Multi-Chain Deployment Script Complexity
- **Mitigation**: Foundry スクリプトで環境変数ベースのチェーン切り替え実装、各チェーンごとにテスト実行

## References

### Circle USDC Documentation
- [USDC Contract Addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses) - 公式 USDC コントラクトアドレス一覧
- [Circle Testnet Faucet](https://faucet.circle.com/) - USDC Testnet Faucet

### Arc Documentation
- [Arc Contract Addresses](https://docs.arc.network/arc/references/contract-addresses) - Arc Testnet USDC アドレス
- [Arc Getting Started](https://lablab.ai/ai-tutorials/getting-started-with-arc-testnet-send-usdc-with-ethersjs) - Arc Testnet USDC 転送チュートリアル

### World Chain Documentation
- [World Chain Testnet Info](https://docs.world.org/world-chain/quick-start/info) - World Chain Sepolia ネットワーク情報
- [World Chain Faucet](https://www.l2faucet.com/world) - World Chain Testnet Faucet
- [Alchemy World Chain Sepolia Faucet](https://www.alchemy.com/faucets/world-chain-sepolia) - Alchemy提供のFaucet

### Base Sepolia Documentation
- [Base Sepolia USDC on BaseScan](https://sepolia.basescan.org/token/0x036cbd53842c5426634e7929541ec2318f3dcf7e) - Base Sepolia USDC コントラクト

### OpenZeppelin Documentation
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/) - OpenZeppelin Contracts v5.x ドキュメント

### Foundry Documentation
- [Foundry Book - Deploying](https://book.getfoundry.sh/forge/deploying) - Foundry デプロイガイド
- [Foundry Book - Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting) - Foundry スクリプティングチュートリアル
