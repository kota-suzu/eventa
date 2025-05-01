module AuthHelpers
  # テスト用にJWTトークンを生成するメソッド
  def generate_token_for_user(user)
    payload = {
      user_id: user.id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, "HS256")
  end

  # 認証ヘッダーを設定するメソッド
  def auth_headers_for(user)
    token = generate_token_for_user(user)
    {"Authorization" => "Bearer #{token}"}
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
