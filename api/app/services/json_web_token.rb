class JsonWebToken
  # 秘密鍵を確実に文字列として取得
  SECRET = Rails.configuration.x.jwt[:secret].to_s

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
