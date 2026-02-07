# Requirements Document

## Introduction

本仕様は、Ghost Yield プロジェクトにおける L2 稼働率オラクルの本格実装に関する要件を定義する。現在モックとなっている `MockOracle.sol` を、Block Fullness の EMA（指数移動平均）を指標とするプロダクションレベルのオラクルに拡張する。高頻度のオフチェーン bot 更新と、低頻度の Chainlink Functions による検証を組み合わせたハイブリッド方式を採用し、信頼性・安全性・監査可能性を確保する。

**対象チェーン**: Base Sepolia / Unichain Sepolia
**デフォルトパラメータ**: EMA窓 60ブロック相当、bot更新 60秒、Functions検証 15分、乖離閾値 15pt、TTL 20分

## Requirements

### Requirement 1: 稼働率指標の算出と保存

**Objective:** As a オラクルコントラクト利用者, I want L2チェーンの稼働率が標準化された指標として算出・保存されること, so that Uniswap v4 Hookが信頼性のあるデータに基づいて動的手数料を決定できる

#### Acceptance Criteria
1. The Oracle Contract shall `utilization` を `EMA(gasUsed / gasLimit) * 100` の整数値（0〜100）として保存する
2. When `utilization` が 100 を超える値で更新リクエストされた場合, the Oracle Contract shall トランザクションを revert する
3. When `utilization` が正常な範囲（0〜100）で更新された場合, the Oracle Contract shall `updatedAt` タイムスタンプを同時に記録する
4. The Oracle Contract shall 更新ソースを `source` フィールドで識別する（1=bot, 2=functions）
5. When `getUtilizationWithMeta()` が呼び出された場合, the Oracle Contract shall `utilization`, `updatedAt`, `stale` フラグ, `source` を返す

### Requirement 2: ハイブリッド更新メカニズム

**Objective:** As a システム運用者, I want 高頻度のbot更新と低頻度のChainlink Functions検証を併用したハイブリッド更新方式, so that 高い更新頻度と独立した検証の両方を実現できる

#### Acceptance Criteria
1. When オフチェーンbotが `setUtilizationFromBot()` を呼び出した場合, the Oracle Contract shall `utilization` と `timestamp` を記録し、`source=1` を設定する
2. When Chainlink Functionsが `setUtilizationFromFunctions()` を呼び出した場合, the Oracle Contract shall `utilization`, `timestamp`, `requestId` を記録し、`source=2` を設定する
3. When bot値とFunctions値の乖離が閾値（デフォルト15ポイント）を超えた場合, the Oracle Contract shall Functions側の値を優先的に採用する
4. The Oracle Contract shall bot更新とFunctions更新を独立して受け付け、一方の障害が他方に影響しないようにする

### Requirement 3: アクセス制御と権限管理

**Objective:** As a コントラクト管理者, I want オラクル更新の書き込み権限をallowlist方式で管理できること, so that 認可されたアドレスのみがデータを更新でき、不正な操作を防止できる

#### Acceptance Criteria
1. When 管理者が `setAuthorizedUpdater(address, bool)` を呼び出した場合, the Oracle Contract shall 指定アドレスの更新権限を設定する
2. If allowlistに含まれないアドレスが `setUtilizationFromBot()` または `setUtilizationFromFunctions()` を呼び出した場合, the Oracle Contract shall トランザクションを revert する
3. When 更新権限が変更された場合, the Oracle Contract shall `UpdaterAuthorizationChanged(address, bool)` イベントを発行する
4. The Oracle Contract shall `setAuthorizedUpdater()` の呼び出しをオーナーまたは管理者ロールに制限する
5. The Oracle Contract shall 既存の `setUtilization(uint256)` 関数を後方互換性を維持しつつ、内部的にallowlistチェックに統合する

### Requirement 4: データ鮮度管理（TTL / Stale検出）

**Objective:** As a Hookコントラクト, I want オラクルデータの鮮度を自動判定できること, so that 古いデータに基づく危険な手数料設定を防止できる

#### Acceptance Criteria
1. The Oracle Contract shall `updatedAt` と `staleTtl`（デフォルト20分）を保持する
2. When `block.timestamp - updatedAt > staleTtl` の場合, the Oracle Contract shall `stale` フラグを `true` として返す
3. When 管理者が `setStaleTtl(uint256)` を呼び出した場合, the Oracle Contract shall TTL値を更新し `TtlUpdated(uint256)` イベントを発行する
4. While オラクルが初期化直後で一度も更新されていない状態の場合, the Oracle Contract shall `stale=true` を返す
5. When 新しい `utilization` 値が正常に書き込まれた場合, the Oracle Contract shall `stale` フラグを `false` にリセットする

### Requirement 5: Hookとの統合（安全な手数料決定）

**Objective:** As a Uniswap v4 Hookコントラクト, I want オラクルのメタ情報を活用してswap手数料を安全に決定すること, so that staleデータ時に危険な低手数料が適用されるリスクを排除できる

#### Acceptance Criteria
1. When swap実行時に `UtilizationHook` がオラクルを参照する場合, the UtilizationHook shall `getUtilizationWithMeta()` を使用してメタ情報付きのデータを取得する
2. If `stale == true` の場合, the UtilizationHook shall `DEFAULT_FEE` を強制的に適用する
3. While `stale == false` の場合, the UtilizationHook shall `utilization` 値に基づいて動的手数料を算出する
4. The UtilizationHook shall 手数料決定ロジックを deterministic（同一入力に対して同一出力）とする

### Requirement 6: オフチェーンBot更新コンポーネント

**Objective:** As a システム運用者, I want オフチェーンbotが各L2のBlock Fullnessを定期的に取得・計算・送信すること, so that オラクルが高頻度で最新の稼働率データを保持できる

#### Acceptance Criteria
1. The Oracle Updater Bot shall 対象L2チェーンの最新ブロック群から `gasUsed` と `gasLimit` を取得する
2. The Oracle Updater Bot shall 取得したデータからEMA（60ブロック相当の窓）を計算し、0〜100の整数値に変換する
3. The Oracle Updater Bot shall 設定された間隔（デフォルト60秒）で `setUtilizationFromBot()` を呼び出す
4. If RPCエンドポイントへの接続が失敗した場合, the Oracle Updater Bot shall 副系RPCにフォールバックする
5. The Oracle Updater Bot shall 設定ファイルからRPC主副、EMA係数、更新間隔、コントラクトアドレスを読み込む

### Requirement 7: Chainlink Functions検証コンポーネント

**Objective:** As a システム設計者, I want Chainlink Functionsが独立してBlock Fullnessを再計算し、bot値を検証すること, so that 単一障害点を排除しオラクルデータの信頼性を二重に担保できる

#### Acceptance Criteria
1. The Chainlink Functions Source shall 対象L2のRPCから直接ブロックデータを取得し、bot側と同一のEMA計算式で稼働率を算出する
2. The Chainlink Functions Source shall 設定された間隔（デフォルト15分）で定期実行される
3. When Functions実行が完了した場合, the Oracle Contract shall `setUtilizationFromFunctions()` を通じて検証値を記録する
4. The Chainlink Functions Deployment Script shall Router, Subscription ID, ソースコードの登録を自動化する
5. If Chainlink Functions実行が失敗した場合, the Oracle Contract shall 既存のbot更新値を維持し、サービスを継続する

### Requirement 8: 監査可能性とイベント発行

**Objective:** As a 監査者・運用監視者, I want すべてのオラクル更新と設定変更がイベントとして記録されること, so that bot/Functions両経路の更新履歴を追跡し、異常を検知できる

#### Acceptance Criteria
1. When `utilization` が更新された場合, the Oracle Contract shall `UtilizationUpdated(uint256 utilization, uint8 source, uint256 updatedAt)` イベントを発行する
2. When 更新者の権限が変更された場合, the Oracle Contract shall `UpdaterAuthorizationChanged(address updater, bool allowed)` イベントを発行する
3. When TTLが変更された場合, the Oracle Contract shall `TtlUpdated(uint256 ttlSeconds)` イベントを発行する
4. The Oracle Contract shall イベントの `source` フィールドにより bot(1) と Functions(2) の更新を明確に区別する

### Requirement 9: 安全性と障害耐性

**Objective:** As a プロトコル利用者, I want オラクルが障害時にも安全側に倒れること, so that 更新停止や異常データにより不正な低手数料が適用されるリスクを排除できる

#### Acceptance Criteria
1. If botとChainlink Functionsの両方が停止し、TTLを超過した場合, the UtilizationHook shall `DEFAULT_FEE` を適用して安全側の手数料を維持する
2. If 未来のタイムスタンプ（`timestamp > block.timestamp`）で更新が試みられた場合, the Oracle Contract shall トランザクションを revert する
3. If 極端に古いタイムスタンプで更新が試みられた場合, the Oracle Contract shall トランザクションを revert する
4. While Chainlink Functions が一時的に利用不能な場合, the Oracle Contract shall bot更新を継続して受け付ける
5. The Oracle Contract shall 初期状態（未更新）で `stale=true` を返し、`DEFAULT_FEE` が適用されるようにする

### Requirement 10: 後方互換性

**Objective:** As a 既存コントラクト統合者, I want 既存の `setUtilization()` インターフェースが引き続き動作すること, so that 既存のテストやスクリプトが破壊されずにオラクルの強化が行える

#### Acceptance Criteria
1. The Oracle Contract shall 既存の `setUtilization(uint256)` 関数シグネチャを維持する
2. When `setUtilization(uint256)` が呼び出された場合, the Oracle Contract shall 内部的にallowlistチェックを適用した上で値を更新する
3. The Oracle Contract shall 既存の `getUtilization()` 関数を維持し、`utilization` 値のみを返す
4. The Oracle Contract shall `IMockOracle` インターフェースの既存メソッドとの互換性を保つ

### Requirement 11: 設定管理

**Objective:** As a 開発者・運用者, I want オラクル関連の設定を一元管理できること, so that 環境ごとのパラメータ変更やデプロイが容易に行える

#### Acceptance Criteria
1. The Configuration Module shall RPC主副エンドポイント、EMA係数、bot更新間隔、Functions検証間隔、乖離閾値、TTLをファイルで管理する
2. The Configuration Module shall Chainlink Functions の Router アドレス、Subscription ID を保持する
3. The Configuration Module shall チェーンごと（Base Sepolia / Unichain Sepolia）に異なる設定値をサポートする
4. When 設定値が環境変数で上書き指定された場合, the Configuration Module shall 環境変数の値を優先する
