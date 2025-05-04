#!/bin/bash
set -e

echo "認証問題修正スクリプト開始..."

# 1. JWTイニシャライザの修正
echo "JWTイニシャライザを更新中..."
cat > config/initializers/jwt.rb << 'EOL'
# JWTの設定
Rails.configuration.x.jwt = {
  # 開発・テスト環境では固定の秘密鍵を使用
  # 本番環境では環境変数または認証情報を使用
  secret: if Rails.env.production?
            ENV["JWT_SECRET_KEY"]
          else
            # 開発とテスト環境では同じ固定キーを使用して、テスト実行時の互換性を確保
            "development_test_fixed_key_for_jwt_eventa_app_2025"
          end
}
EOL
echo "JWT設定を修正しました"

# 2. 認証コントローラの修正
echo "認証コントローラを確認中..."
AUTH_CONTROLLER=$(find app/controllers/api/v1 -name "*auth*controller.rb" -o -name "*auths_controller.rb" | head -1)
if [ -n "$AUTH_CONTROLLER" ]; then
  echo "認証コントローラを見つけました: $AUTH_CONTROLLER"
  if grep -q "skip_before_action :authenticate_user" "$AUTH_CONTROLLER"; then
    echo "認証スキップ設定が既にあります"
  else
    sed -i '1a\  skip_before_action :authenticate_user, only: [:login, :register]' "$AUTH_CONTROLLER"
    echo "認証スキップ設定を追加しました"
  fi
else
  echo "認証コントローラが見つかりません"
fi

# 3. ユーザーファクトリーの修正
echo "ユーザーファクトリーを確認中..."
if [ -f spec/factories/users.rb ]; then
  echo "ユーザーファクトリーが見つかりました"
  if grep -q "password" spec/factories/users.rb; then
    echo "パスワード設定が既にあります"
    sed -i '/password/s/.*password.*/    password { "password123" }/' spec/factories/users.rb
    sed -i '/password_confirmation/s/.*password_confirmation.*/    password_confirmation { "password123" }/' spec/factories/users.rb
    echo "パスワード設定を修正しました"
  else
    FACTORY_LINE=$(grep -n "end" spec/factories/users.rb | head -1 | cut -d: -f1)
    INDENTATION=$(sed -n "${FACTORY_LINE}p" spec/factories/users.rb | sed -E 's/^([[:space:]]*)end.*/\1/')
    INSERT_LINE=$((FACTORY_LINE - 1))
    sed -i "${INSERT_LINE}a\\${INDENTATION}  password { \"password123\" }\\n${INDENTATION}  password_confirmation { \"password123\" }" spec/factories/users.rb
    echo "パスワード設定を追加しました"
  fi
else
  echo "ユーザーファクトリーが見つかりません"
fi

# 4. 認証テストヘルパーの作成
echo "認証テストヘルパーを作成中..."
mkdir -p spec/support
cat > spec/support/auth_test_helper.rb << 'EOL'
# 認証テスト補助モジュール
module AuthTestHelper
  # テスト用にユーザーを作成し、認証済みセッションを提供
  def create_authenticated_user(attributes = {})
    user = FactoryBot.create(:user, attributes)
    # パスワードが確実に設定されるよう明示的に確認
    user.update(password: "password123", password_confirmation: "password123") unless user.authenticate("password123")
    user
  end

  # テスト用にJWTトークンを生成
  def generate_token_for(user)
    JsonWebToken.encode({user_id: user.id})
  end

  # 認証ヘッダー付きのリクエストを行うヘルパー
  def auth_headers_for(user)
    token = generate_token_for(user)
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end
end

# RSpecに組み込み
RSpec.configure do |config|
  config.include AuthTestHelper, type: :request
  config.include AuthTestHelper, type: :controller
end
EOL
echo "認証テストヘルパーを作成しました"

echo "認証問題修正スクリプト完了"
echo "テストを実行するには: bundle exec rspec" 