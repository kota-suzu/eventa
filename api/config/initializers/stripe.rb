# frozen_string_literal: true

# Stripe APIキーの設定
# 本番環境では適切に暗号化された環境変数から取得すること
Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", "sk_test_dummy")

# Stripeからのイベントの署名検証用キー
Rails.configuration.x.stripe = {
  webhook_secret: ENV.fetch("STRIPE_WEBHOOK_SECRET", "whsec_dummy")
}

# ログ出力レベルの設定（開発環境ではデバッグ情報も表示）
Stripe.log_level = Rails.env.production? ? nil : ::Logger::DEBUG
