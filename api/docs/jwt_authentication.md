# JWT認証システム - 開発者ガイド

このドキュメントでは、Eventaアプリケーションで使用されているJWT認証システムの概要、設定方法、テスト方法、および一般的な問題の解決方法について説明します。

## 目次

1. [概要](#概要)
2. [JWT設定](#jwt設定)
3. [トークンブラックリスト機能](#トークンブラックリスト機能)
4. [テスト方法](#テスト方法)
5. [よくある問題と解決方法](#よくある問題と解決方法)
6. [将来的な拡張計画](#将来的な拡張計画)

## 概要

EventaアプリケーションではJWT（JSON Web Token）を使用して認証を行います。これにより、ステートレスな認証が可能になり、APIサーバーのスケーラビリティが向上します。

主要コンポーネント:
- `JsonWebToken`: JWTトークンのエンコード/デコードを担当
- `TokenBlacklistService`: 無効化されたトークンを管理
- `Api::V1::AuthsController`: 認証エンドポイントを提供

## JWT設定

### 基本設定

JWT認証の設定は `config/initializers/jwt.rb` で行います:

```ruby
# 基本設定
SECRET_KEY = Rails.env.production? ? ENV["JWT_SECRET_KEY"] : "development_test_fixed_key_for_jwt_eventa_app_2025"
ALGORITHM = "HS256"
TOKEN_EXPIRY = 24.hours
ISSUER = "eventa-api"
AUDIENCE = "eventa-client"
```

### 環境変数

本番環境では以下の環境変数を設定してください:

- `JWT_SECRET_KEY`: JWTの署名に使用する秘密鍵
- `REDIS_URL`: トークンブラックリスト用のRedis接続URL

## トークンブラックリスト機能

`TokenBlacklistService`はRedisを使用して無効化されたトークンを管理します。ログアウト時や、セキュリティ上の理由でトークンを無効化する際に使用します。

### 主な機能

- `add(token, reason = "logout")`: トークンをブラックリストに追加
- `blacklisted?(token)`: トークンがブラックリストに登録されているかを確認
- `remove_refresh_token(token)`: リフレッシュトークンを削除
- `invalidate_all_for_user(user_id, reason = "security_concern")`: ユーザーのすべてのトークンを無効化

### 実装上の注意点

- JTIがないトークン：JTI（JWT ID）がないトークンは常にブラックリスト扱いになります。これはセキュリティ上の理由からです。
- 有効期限切れトークン：既に有効期限が切れているトークンはブラックリストに追加する必要がなく、自動的に拒否されます。
- Redis障害時の動作：Redis接続エラー時は安全側に倒し、トークン検証時には「ブラックリストに登録されている」と判断します。

## テスト方法

### JWT認証テスト環境の準備

テスト環境でJWT認証をテストするには、以下のRakeタスクを使用できます：

```bash
RAILS_ENV=test bundle exec rake jwt:test:setup
```

このタスクは以下を行います：
- Rails 8互換の暗号化キー設定
- JWT初期化設定の検証
- テスト用Redisモックの設定（必要に応じて）

### JWT機能のテスト実行

JWT認証関連の機能をテストするには：

```bash
RAILS_ENV=test bundle exec rake jwt:test:run
```

このタスクは以下をテストします：
- JWTエンコード/デコード機能
- 有効期限の検証
- TokenBlacklistServiceの動作

### RSpecでのJWT関連テスト

RSpecでJWT関連のテストを実行する場合：

```bash
RAILS_ENV=test bundle exec rspec spec/services/json_web_token_spec.rb spec/services/token_blacklist_service_spec.rb
```

## よくある問題と解決方法

### Rails 8での暗号化エラー

**症状**: Rails 8環境でテスト実行時に `ActiveSupport::MessageEncryptor::InvalidMessage` エラーが発生

**解決方法**:
1. 暗号化キーの長さを16バイトに設定
   ```ruby
   Rails.application.credentials.config.secret_key_base = "0123456789abcdef"
   ```

2. 環境変数を設定
   ```bash
   export RAILS_MASTER_KEY=0123456789abcdef
   export SECRET_KEY_BASE=0123456789abcdef0123456789abcdef
   ```

3. テスト専用のRakeタスクを使用
   ```bash
   RAILS_ENV=test bundle exec rake jwt:test:run
   ```

### Redisエラー

**症状**: `Redis::CannotConnectError` エラーが発生

**解決方法**:
1. Redis接続が利用可能かを確認
   ```bash
   redis-cli ping
   ```

2. テスト用のRedisモックを使用
   ```ruby
   class MockRedis
     # ... (モックの実装)
   end
   
   TokenBlacklistService.redis = MockRedis.new
   ```

## 将来的な拡張計画

JWT認証システムでは以下の機能の追加を計画しています：

1. JWTアルゴリズムをHS256からRS256へ変更（非対称暗号化）
2. リフレッシュトークンフローの最適化
3. トークン使用状況の監視とレポート機能
4. 多要素認証（MFA）対応
5. トークン無効化の整合性強化

これらの拡張は、TODO.mdファイルにリストされているタスクの一部です。実装詳細については、プロジェクトリーダーに相談してください。 