# Eventa認証システム開発ガイド

**ステータス**: Active  
**作成日**: 2025-05-04  
**作成者**: Security Team

## 目次

1. [認証システム概要](#認証システム概要)
2. [開発環境のセットアップ](#開発環境のセットアップ)
3. [認証関連のコード構成](#認証関連のコード構成)
4. [JWT実装の詳細](#jwt実装の詳細)
5. [リフレッシュトークンの実装](#リフレッシュトークンの実装)
6. [テスト方法](#テスト方法)
7. [デバッグとトラブルシューティング](#デバッグとトラブルシューティング)
8. [セキュリティのベストプラクティス](#セキュリティのベストプラクティス)

## 認証システム概要

Eventaの認証システムは、JWT（JSON Web Token）とリフレッシュトークンを組み合わせた安全で使いやすい認証フローを実装しています。

### 主な特徴

- **JWTによるステートレス認証**: APIリクエストごとにトークン検証
- **リフレッシュトークン**: 長期間のセッション維持と安全なトークン更新
- **セキュアなクッキー**: HttpOnly, Secure, SameSite属性の使用
- **マルチプラットフォーム対応**: Web, モバイル, サードパーティーAPIの各クライアント対応
- **標準的なJWTクレーム**: 発行者(iss), 対象者(aud), 発行時刻(iat)などの検証

### 認証フロー

1. **ユーザー登録/ログイン**:
   - 認証情報の検証後、アクセストークンとリフレッシュトークンを発行
   - トークンはレスポンスボディとHttpOnlyクッキーの両方で提供

2. **APIリクエスト**:
   - `Authorization: Bearer {token}`ヘッダーでアクセストークンを送信
   - サーバーはトークンを検証し、ユーザー情報とロールを抽出

3. **トークン更新**:
   - アクセストークンの期限切れ時、リフレッシュトークンを使用して新規アクセストークンを取得
   - リフレッシュトークン自体も定期的に更新される

## 開発環境のセットアップ

### 必要なパッケージ

認証システムは以下のgemに依存しています：

```ruby
# Gemfile
gem 'jwt', '~> 2.7'        # JWT生成・検証
gem 'bcrypt', '~> 3.1.18'  # パスワードハッシュ化
```

### 環境変数の設定

開発環境では`.env`ファイルに以下の変数を設定します：

```
# JWT設定（開発・テスト環境）
JWT_SECRET_KEY=development_test_fixed_key_for_jwt_eventa_app_2025
JWT_EXPIRATION_HOURS=24
JWT_REFRESH_EXPIRATION_DAYS=30
```

本番環境では`Rails.application.credentials`を使ってシークレットを管理します：

```
rails credentials:edit
```

```yaml
# config/credentials.yml.enc の内容例
jwt:
  secret: your_strong_production_secret_key_here
```

## 認証関連のコード構成

### コントローラー

- `app/controllers/application_controller.rb`: 認証の共通処理
- `app/controllers/api/v1/auths_controller.rb`: 認証エンドポイント処理

### サービス

- `app/services/json_web_token.rb`: JWT生成・検証ロジック

### モデル

- `app/models/user.rb`: ユーザー認証ロジック

## JWT実装の詳細

### JsonWebTokenサービス

`app/services/json_web_token.rb`ではJWTの生成と検証を担当します：

```ruby
class JsonWebToken
  SECRET = Rails.configuration.x.jwt[:secret].to_s
  DEFAULT_EXP = Rails.configuration.x.jwt[:expiration] || 24.hours
  ISSUER = "eventa-api-#{Rails.env}"
  AUDIENCE = "eventa-client"

  class << self
    # JWTトークンのエンコード
    def encode(payload, exp = DEFAULT_EXP)
      payload = payload.dup
      now = Time.current.to_i
      
      # セキュリティ強化のための標準クレーム
      payload[:iss] = ISSUER            # 発行者
      payload[:aud] = AUDIENCE          # 対象者
      payload[:iat] = now               # 発行時刻
      payload[:nbf] = now               # 有効開始時刻
      payload[:jti] = SecureRandom.uuid # 一意のトークンID
      payload[:exp] = exp.from_now.to_i # 有効期限
      
      JWT.encode(payload, SECRET, "HS256")
    end

    # JWTトークンのデコード
    def decode(token)
      decoded = JWT.decode(
        token, 
        SECRET, 
        true, 
        {
          algorithm: "HS256",
          verify_iss: true,
          iss: ISSUER,
          verify_aud: true,
          aud: AUDIENCE,
          verify_iat: true,
          leeway: 30 # 30秒の時間差を許容
        }
      )
      decoded[0]
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError, JWT::InvalidIssuerError, JWT::InvalidAudError => e
      Rails.logger.error("JWT decode error: #{e.class} - #{e.message}")
      nil
    end
    
    # リフレッシュトークンの生成
    def generate_refresh_token(user_id)
      session_id = SecureRandom.hex(16)
      refresh_exp = Rails.configuration.x.jwt[:refresh_expiration] || 30.days
      
      payload = {
        user_id: user_id,
        session_id: session_id,
        token_type: 'refresh'
      }
      
      token = encode(payload, refresh_exp)
      [token, session_id]
    end
  end
end
```

### JWT設定の初期化

`config/initializers/jwt.rb`でJWT設定を初期化します：

```ruby
Rails.configuration.x.jwt = {
  secret: if Rails.env.production?
            Rails.application.credentials.dig(:jwt, :secret) || ENV["JWT_SECRET_KEY"]
          else
            "development_test_fixed_key_for_jwt_eventa_app_2025"
          end,
  
  expiration: ENV.fetch("JWT_EXPIRATION_HOURS", "24").to_i.hours,
  refresh_expiration: ENV.fetch("JWT_REFRESH_EXPIRATION_DAYS", "30").to_i.days
}
```

## リフレッシュトークンの実装

### トークン更新エンドポイント

`app/controllers/api/v1/auths_controller.rb`にリフレッシュトークン処理を実装：

```ruby
# POST /api/v1/auth/refresh
def refresh_token
  # リフレッシュトークンを取得
  refresh_token = extract_refresh_token
  
  if refresh_token.blank?
    return render json: { error: "リフレッシュトークンが見つかりません" }, status: :unauthorized
  end
  
  # リフレッシュトークンをデコード
  payload = JsonWebToken.decode(refresh_token)
  
  if payload.nil? || payload["token_type"] != "refresh"
    return render json: { error: "無効なリフレッシュトークン" }, status: :unauthorized
  end
  
  # ユーザーが存在するか確認
  user = User.find_by(id: payload["user_id"])
  
  if user.nil?
    return render json: { error: "ユーザーが見つかりません" }, status: :unauthorized
  end
  
  # 新しいアクセストークンを生成
  new_token = generate_jwt_token(user)
  
  # Cookieに新しいトークンを設定
  set_jwt_cookie(new_token)
  
  render json: {
    token: new_token,
    user: user_response(user)
  }
end

# リフレッシュトークン取得ヘルパー
def extract_refresh_token
  # Cookieからリフレッシュトークンを取得
  token_from_cookie = cookies.signed[:refresh_token]
  return token_from_cookie if token_from_cookie.present?
  
  # ヘッダーからも取得可能にする
  header = request.headers["X-Refresh-Token"]
  return header if header.present?
  
  # ボディからも取得可能にする
  params[:refresh_token]
end
```

### Cookie管理

```ruby
def set_jwt_cookie(token)
  cookies.signed[:jwt] = {
    value: token,
    httponly: true,
    secure: Rails.env.production?,
    same_site: :lax,
    expires: 24.hours.from_now
  }
end

def set_refresh_token_cookie(token)
  cookies.signed[:refresh_token] = {
    value: token,
    httponly: true,
    secure: Rails.env.production?,
    same_site: :lax,
    expires: 30.days.from_now
  }
end
```

## テスト方法

### 単体テスト

JWT関連のテストは`spec/services/json_web_token_spec.rb`に実装します：

```ruby
require 'rails_helper'

RSpec.describe JsonWebToken do
  describe '.encode' do
    it 'generates a valid JWT token' do
      payload = { user_id: 1 }
      token = JsonWebToken.encode(payload)
      
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # ヘッダー.ペイロード.署名
    end
    
    it 'includes standard security claims' do
      payload = { user_id: 1 }
      token = JsonWebToken.encode(payload)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      expect(decoded).to include('iss', 'aud', 'iat', 'nbf', 'jti', 'exp')
      expect(decoded['iss']).to eq(JsonWebToken::ISSUER)
      expect(decoded['aud']).to eq(JsonWebToken::AUDIENCE)
    end
  end
  
  describe '.decode' do
    it 'correctly decodes a valid token' do
      payload = { user_id: 1 }
      token = JsonWebToken.encode(payload)
      decoded = JsonWebToken.decode(token)
      
      expect(decoded).to include('user_id')
      expect(decoded['user_id']).to eq(1)
    end
    
    it 'returns nil for an invalid token' do
      result = JsonWebToken.decode('invalid.token.string')
      expect(result).to be_nil
    end
    
    it 'returns nil for an expired token' do
      payload = { user_id: 1 }
      expired_token = JsonWebToken.encode(payload, -1.hour)
      result = JsonWebToken.decode(expired_token)
      expect(result).to be_nil
    end
  end
  
  describe '.generate_refresh_token' do
    it 'generates a refresh token with session ID' do
      token, session_id = JsonWebToken.generate_refresh_token(1)
      
      expect(token).to be_a(String)
      expect(session_id).to be_a(String)
      expect(session_id.length).to eq(32) # 16バイト（hex表現で32文字）
      
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      expect(decoded['user_id']).to eq(1)
      expect(decoded['session_id']).to eq(session_id)
      expect(decoded['token_type']).to eq('refresh')
    end
  end
end
```

### 統合テスト

認証エンドポイントのテストは`spec/requests/api/v1/auths_spec.rb`に実装します：

```ruby
require 'rails_helper'

RSpec.describe "Api::V1::Auths", type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  
  describe "POST /api/v1/auth/login" do
    context '有効な認証情報' do
      it 'トークンとリフレッシュトークンを返す' do
        post '/api/v1/auth/login', params: { email: user.email, password: 'password123' }
        
        expect(response).to have_http_status(:success)
        expect(json_response).to include('token', 'refresh_token', 'user')
        expect(json_response['user']['id']).to eq(user.id)
        
        # クッキーの検証
        expect(response.cookies['jwt']).to be_present
        expect(response.cookies['refresh_token']).to be_present
      end
    end
    
    context '無効な認証情報' do
      it '401エラーを返す' do
        post '/api/v1/auth/login', params: { email: user.email, password: 'wrong_password' }
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response).to include('error')
      end
    end
  end
  
  describe "POST /api/v1/auth/refresh" do
    let(:refresh_token) { JsonWebToken.generate_refresh_token(user.id)[0] }
    
    context '有効なリフレッシュトークン' do
      it '新しいアクセストークンを返す' do
        post '/api/v1/auth/refresh', params: { refresh_token: refresh_token }
        
        expect(response).to have_http_status(:success)
        expect(json_response).to include('token', 'user')
        expect(json_response['user']['id']).to eq(user.id)
        
        # クッキーの検証
        expect(response.cookies['jwt']).to be_present
      end
    end
    
    context '無効なリフレッシュトークン' do
      it '401エラーを返す' do
        post '/api/v1/auth/refresh', params: { refresh_token: 'invalid_token' }
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response).to include('error')
      end
    end
  end
end
```

## デバッグとトラブルシューティング

### JWTデバッグ方法

1. **トークンの内容確認**:
   ```bash
   # JWTの中身をデコードして表示（有効性検証なし）
   ruby -r jwt -e 'puts JWT.decode(ARGV[0], nil, false)' eyJhbGciOiJIUzI1NiJ9...
   ```

2. **Railsコンソールでのデバッグ**:
   ```ruby
   # アクセストークン検証
   token = "eyJhbGciOiJIUzI1NiJ9..."
   puts JsonWebToken.decode(token)
   
   # リフレッシュトークン生成と検証
   refresh_token, session_id = JsonWebToken.generate_refresh_token(1)
   puts JsonWebToken.decode(refresh_token)
   ```

3. **cURLでのテスト**:
   ```bash
   # ログイン
   curl -X POST http://localhost:3001/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"auth":{"email":"test@example.com","password":"password123"}}' \
     -v
   
   # トークン更新
   curl -X POST http://localhost:3001/api/v1/auth/refresh \
     -H "Content-Type: application/json" \
     -H "X-Refresh-Token: eyJhbGciOiJIUzI1NiJ9..." \
     -v
   ```

### 一般的な問題と解決策

1. **401エラー（認証失敗）**:
   - JWTの有効期限切れ → リフレッシュトークン使用
   - 無効なシグネチャ → 環境間でのシークレットキー不一致を確認
   - 発行者(iss)や対象者(aud)の不一致 → クライアント側の値を確認

2. **クッキーの問題**:
   - Cookie設定エラー → APIモードでActionController::Cookiesの追加確認
   - SameSite制約 → クロスサイトリクエストでの制限を確認
   - HTTPSのみのCookie → 開発環境でSecure属性をfalseに設定

3. **クロスオリジン問題**:
   - CORSエラー → `config/initializers/cors.rb`の設定を確認

## セキュリティのベストプラクティス

1. **JWT使用時の注意点**:
   - トークンの有効期限を短く設定（24時間以内）
   - 機密データをJWTに含めない
   - 強力なシグネチャキーを使用

2. **リフレッシュトークンのセキュリティ**:
   - HttpOnly Cookieで保存
   - 使い捨て（使用後に更新）
   - セッションストアでの管理（将来の実装）

3. **全般的なセキュリティ対策**:
   - 本番環境では常にHTTPS使用
   - レート制限の実装
   - 認証試行回数の制限
   - ログインイベントの監査ロギング
   - 定期的なセキュリティレビュー 