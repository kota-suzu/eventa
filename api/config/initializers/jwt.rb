# JWTの設定
Rails.configuration.x.jwt = {
  # 本番環境ではcredentialsまたは環境変数から安全に秘密鍵を取得
  # 開発・テスト環境では固定の秘密鍵を使用
  secret: if Rails.env.production?
            # 優先順位: 1. credentials 2. 環境変数
            Rails.application.credentials.dig(:jwt, :secret) || ENV["JWT_SECRET_KEY"]
          else
            # 開発とテスト環境では同じ固定キーを使用して、テスト実行時の互換性を確保
            "development_test_fixed_key_for_jwt_eventa_app_2025"
          end,

  # トークンの有効期限（時間単位、デフォルト24時間）
  expiration: ENV.fetch("JWT_EXPIRATION_HOURS", "24").to_i.hours,

  # リフレッシュトークンの有効期限（日単位、デフォルト30日）
  refresh_expiration: ENV.fetch("JWT_REFRESH_EXPIRATION_DAYS", "30").to_i.days
}

# Rails.logger.debug "JWT Secret: #{Rails.configuration.x.jwt[:secret][0..5]}..." if Rails.env.development?
