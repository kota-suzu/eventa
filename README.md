# Eventa

Eventaは、イベント管理・予約システムです。

## 目次

- [セットアップ](#セットアップ)
- [機能概要](#機能概要)
- [アーキテクチャ](#アーキテクチャ)
- [認証システム](#認証システム)
- [API仕様](#api仕様)
- [テスト](#テスト)
  - [認証システムテスト](#認証システムテスト)
  - [テストカバレッジ](#テストカバレッジ)
- [開発者向けドキュメント](#開発者向けドキュメント)
- [貢献方法](#貢献方法)
- [ライセンス](#ライセンス)

## セットアップ

```bash
# リポジトリのクローン
git clone https://github.com/your-organization/eventa.git
cd eventa

# Docker環境のセットアップ（推奨）
make setup

# または手動セットアップ
# 依存関係のインストール
bundle install

# データベースのセットアップ（MySQL）
rails db:create
# リッジポールを使用したスキーマ適用
bundle exec ridgepole -c config/database.yml -E development --apply -f db/Schemafile
bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile

# サーバーの起動
rails s
```

## 機能概要

Eventaは以下の主要機能を提供します：

- ユーザー認証・認可
- イベント作成・管理
- イベント検索・フィルタリング
- イベント予約・キャンセル
- 支払い処理
- 通知機能

## アーキテクチャ

Eventaは以下の技術スタックで構築されています：

- **バックエンド**: Ruby on Rails APIモード
- **フロントエンド**: React + TypeScript
- **データベース**: MySQL 8.0
- **キャッシュ**: Redis
- **認証**: JWT (JSON Web Tokens)

## 認証システム

Eventaは、JWTベースの認証システムを採用しています。

- アクセストークン（短期有効）とリフレッシュトークン（長期有効）の2つのトークンを使用
- セキュアなHTTPOnlyクッキーによるリフレッシュトークン管理
- 認証関連の詳細については[認証設計ドキュメント](docs/design/auth_design.md)を参照

## API仕様

API仕様は以下の形式で提供されています：

- [OpenAPI仕様書](docs/api/openapi.yaml)
- [API利用ガイド](docs/guides/api_usage.md)

## テスト

テストの実行方法：

```bash
# 全テストの実行
bundle exec rspec

# 特定のテストの実行
bundle exec rspec spec/models/user_spec.rb

# CI環境をシミュレートしたテスト実行（環境問題の診断に役立ちます）
make ci-simulate

# CI環境のデータベース健全性チェック
make ci-healthcheck
```

### 認証システムテスト

認証システムの包括的なテストが実装されています：

```bash
# 認証関連の全テストを実行
bundle exec rspec \
  spec/services/json_web_token_spec.rb \
  spec/models/user_spec.rb \
  spec/requests/api/v1/auths_controller_spec.rb \
  spec/requests/api/v1/auth_api_coverage_spec.rb \
  spec/security/auth_security_spec.rb \
  spec/system/authentication_flow_spec.rb
```

**テスト戦略**:

1. **単体テスト**: 各コンポーネント（JsonWebToken、User）の機能検証
2. **統合テスト**: API エンドポイント（登録、ログイン、トークン更新など）の検証
3. **セキュリティテスト**: トークン改ざん、セッション固定攻撃などの防御検証
4. **エンドツーエンドテスト**: ユーザーフロー（登録からログアウトまで）の検証

### CI環境でのテスト

CI環境では、以下の点に注意してテストを実行しています：

1. **データベース準備**: `rails db:prepare`を使用して一貫したテスト環境を構築
2. **MySQL環境**: すべてのワークフローで統一されたMySQLを使用
3. **環境変数**: 接続情報を環境変数で設定し、異なる環境間での一貫性を確保
4. **テーブル確認**: 重要なテーブルの存在を確認し、不足している場合は早期に検出

CI関連ドキュメント：
- [CI環境のトラブルシューティングガイド](docs/guides/ci_troubleshooting.md)
- [SEGVエラー復旧ガイド](docs/guides/segv-recovery.md)

詳細は[認証テストベストプラクティス](docs/guides/auth_testing_best_practices.md)を参照してください。

### テストカバレッジ

テストカバレッジレポートの生成方法：

```bash
COVERAGE=true bundle exec rspec
```

カバレッジレポートは `coverage/index.html` に生成されます。

**カバレッジ目標**:
- 認証コアコンポーネント: 90%以上
- 全体カバレッジ: 85%以上

## 開発者向けドキュメント

詳細なドキュメントは以下にあります：

- [API設計](docs/design/api_design.md)
- [データベース設計](docs/design/database_design.md)
- [認証設計](docs/design/auth_design.md)
- [デプロイメントガイド](docs/guides/deployment.md)
- [CI環境のトラブルシューティング](docs/guides/ci_troubleshooting.md)

## 貢献方法

1. このリポジトリをフォークする
2. 機能ブランチを作成する (`git checkout -b feature/amazing-feature`)
3. 変更をコミットする (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュする (`git push origin feature/amazing-feature`)
5. プルリクエストを作成する

## ライセンス

[MIT License](LICENSE) 