# テスト環境設定ガイド

## 概要

このドキュメントでは、EventaアプリケーションAPIのテスト環境とその設定方法について説明します。テスト環境では、本番環境とは異なる設定で安全にテストを実行するための仕組みを提供しています。

## 主要なトラブルシューティング

### ActiveSupport::MessageEncryptor::InvalidMessage エラー

Rails 8では認証情報（credentials）の扱いが変更されており、テスト環境でも`master.key`や環境変数の設定が必要になります。このリポジトリでは以下の対策を行いました：

1. テスト環境用の環境変数をMakefileとテスト環境設定ファイルで設定
2. Railsアプリケーションの`credentials`アクセスをテスト環境用にモンキーパッチ

## テスト環境の主要コンポーネント

### 1. 環境変数設定

テスト環境では以下の環境変数を設定しています：

```
RAILS_ENV=test
RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef
SECRET_KEY_BASE=test_secret_key_base_for_safe_testing_only
RAILS_ENCRYPTION_PRIMARY_KEY=00000000000000000000000000000000
RAILS_ENCRYPTION_DETERMINISTIC_KEY=11111111111111111111111111111111
RAILS_ENCRYPTION_KEY_DERIVATION_SALT=2222222222222222222222222222222222222222222222222222222222222222
JWT_SECRET_KEY=test_jwt_secret_key_for_tests_only
GIT_DISCOVERY_ACROSS_FILESYSTEM=1
```

これらの環境変数は以下のファイルで設定されています：

- `Makefile`
- `api/config/environments/test.rb`
- `api/spec/support/credentials_patch.rb`

### 2. モックオブジェクト

テスト環境では外部依存を最小限にするため、以下のサービスをモック化しています：

- `MockRedis`: Redisをメモリ内ストレージで代替
- その他のモックサービス（`api/spec/support/mocks/`ディレクトリ参照）

### 3. カスタムパッチ

テスト環境で安全に実行するために、いくつかのパッチを適用しています：

- `credentials_patch.rb`: Rails.application.credentialsへのアクセスをモック化
- `mock_redis.rb`: TokenBlacklistServiceでのRedis依存をモック化

## テスト実行方法

### 基本的なテスト実行

```bash
# 全テストの実行
make backend-test

# 特定のテストファイル実行
docker compose exec -e RAILS_ENV=test api bundle exec rspec spec/requests/auths_spec.rb

# テスト前にデータベース状態を確認
make db-test-health
```

### 注意点

1. テスト環境では実際のRedisサーバーは使用しないため、Redis接続エラーが発生した場合はモックが正しく設定されているか確認してください。

2. ActiveRecordのデータベース暗号化は、テスト用の固定キーを使用しています。テスト環境で暗号化されたデータは本番環境では復号できません。

3. `GIT_DISCOVERY_ACROSS_FILESYSTEM`環境変数は、Dockerコンテナ内でGit関連の警告メッセージを抑制するために設定しています。

## トラブルシューティング

### テスト実行時にエラーが発生する場合

1. データベース状態の確認: `make db-test-health`
2. データベースのリセット: `make db-test-repair`
3. 環境変数設定確認: `docker compose exec api env | grep RAILS`

### ActiveSupport::MessageEncryptor::InvalidMessage エラーが再発した場合

```bash
# 以下のコマンドでテスト環境用の固定キーを使用して実行
docker compose exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef -e SECRET_KEY_BASE=test_secret_key_base_for_safe_testing_only api bundle exec rspec
```

## TODO

- [ ] `fatal: not a git repository` 警告メッセージを完全に解消するため、コンテナ内にGitリポジトリをマウントするか、すべてのGit関連コマンドをホスト側で実行するよう修正
- [ ] Makefileの環境変数設定を`.env.test`ファイルに移行し、docker-compose.ymlから読み込む方式に変更
- [ ] モックオブジェクトの統一とインターフェースの整理 