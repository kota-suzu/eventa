# JWT設定イニシャライザ
# 環境変数から安全に設定を読み込み
Rails.configuration.x.jwt = {
  # 本番・ステージング環境では環境変数から読み込み
  # 開発・テスト環境では環境変数またはフォールバック値を使用
  secret: if Rails.env.production? || Rails.env.staging?
            # 本番環境では必須（設定されていない場合は例外）
            ENV.fetch("JWT_SECRET_KEY")
          else
            # 開発・テスト環境では環境変数があれば優先、なければフォールバック
            ENV.fetch("JWT_SECRET_KEY_DEV") do
              # Rails.logger.warn "JWT警告: 開発環境で標準的な秘密鍵が使用されています。実運用では環境変数で設定してください。"
              # テスト/開発のみに使用されるフォールバック値
              # 本番環境では絶対に使用されない
              "jwt_dev_key_#{Rails.env}_#{Rails.application.class.module_parent_name.downcase}"
            end
          end,

  # トークンの有効期限（秒単位、デフォルト24時間）
  expiration: ENV.fetch("JWT_EXPIRATION_SECONDS", 24.hours.to_i),

  # リフレッシュトークンの有効期限（秒単位、デフォルト30日）
  refresh_expiration: ENV.fetch("JWT_REFRESH_EXPIRATION_SECONDS", 30.days.to_i)
}
