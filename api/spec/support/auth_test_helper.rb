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

  # 認証済みGETリクエストのショートカット
  def authenticated_get(path, user, params = {})
    get path, params: params, headers: auth_headers_for(user)
  end

  # 認証済みPOSTリクエストのショートカット
  def authenticated_post(path, user, params = {})
    post path, params: params.to_json, headers: auth_headers_for(user)
  end

  # 認証済みPUTリクエストのショートカット
  def authenticated_put(path, user, params = {})
    put path, params: params.to_json, headers: auth_headers_for(user)
  end

  # 認証済みDELETEリクエストのショートカット
  def authenticated_delete(path, user, params = {})
    delete path, params: params.to_json, headers: auth_headers_for(user)
  end

  # トークンの有効期限切れをシミュレート
  def expired_token_for(user)
    payload = {user_id: user.id, exp: 1.day.ago.to_i}
    JWT.encode(payload, Rails.configuration.x.jwt[:secret], "HS256")
  end
end

# RSpecに組み込み
RSpec.configure do |config|
  config.include AuthTestHelper, type: :request
  config.include AuthTestHelper, type: :controller
end
