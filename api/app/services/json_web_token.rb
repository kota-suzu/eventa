class JsonWebToken
  # 秘密鍵をconfigに一元化。テスト時に変更しやすくする
  SECRET = Rails.configuration.x.jwt_secret || Rails.application.credentials.secret_key_base

  class << self
    # JWTトークンのエンコード - expを自動付与
    def encode(payload, exp = 24.hours)
      payload = payload.dup
      payload[:exp] = exp.from_now.to_i
      JWT.encode(payload, SECRET, "HS256")
    end

    # JWTトークンのデコード
    def decode(token)
      decoded = JWT.decode(token, SECRET, true, {algorithm: "HS256"})
      decoded[0]
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      Rails.logger.error("JWT decode error: #{e.message}")
      nil
    end
  end
end
