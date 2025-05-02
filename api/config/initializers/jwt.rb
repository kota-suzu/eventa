# JWTの設定
Rails.configuration.x.jwt = {
  # 開発・テスト環境では固定の秘密鍵を使用
  # 本番環境では環境変数または認証情報を使用
  secret: Rails.env.production? ? ENV['JWT_SECRET_KEY'] : 'development_secret_key_for_jwt_000000000000000000000'
}