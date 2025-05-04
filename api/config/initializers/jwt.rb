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

# Rails.logger.debug "JWT Secret: #{Rails.configuration.x.jwt[:secret][0..5]}..." if Rails.env.development?
