class JsonWebToken
  # 秘密鍵を確実に文字列として取得
  SECRET = Rails.configuration.x.jwt[:secret].to_s
  # デフォルト有効期限
  DEFAULT_EXP = Rails.configuration.x.jwt[:expiration] || 24.hours
  # アプリケーション識別子（発行者）
  ISSUER = "eventa-api-#{Rails.env}"
  # 想定される受信者（サービス名）
  AUDIENCE = "eventa-client"

  class << self
    # JWTトークンのエンコード - expを自動付与
    def encode(payload, exp = DEFAULT_EXP)
      payload = payload.dup
      now = Time.current.to_i
      
      # セキュリティ強化のための標準クレーム
      payload[:iss] = ISSUER            # 発行者
      payload[:aud] = AUDIENCE          # 対象者
      payload[:iat] = now               # 発行時刻
      payload[:nbf] = now               # 有効開始時刻
      payload[:jti] = SecureRandom.uuid # 一意のトークンID
      payload[:exp] = exp.from_now.to_i # 有効期限
      
      JWT.encode(payload, SECRET, "HS256")
    end

    # JWTトークンのデコード
    def decode(token)
      # verify_issでiss（発行者）を検証
      # verify_audienceでaud（対象者）を検証
      # verify_iatで発行時刻を検証
      # leeway：検証時の時間ずれを許容する秒数
      decoded = JWT.decode(
        token, 
        SECRET, 
        true, 
        {
          algorithm: "HS256",
          verify_iss: true,
          iss: ISSUER,
          verify_aud: true,
          aud: AUDIENCE,
          verify_iat: true,
          leeway: 30 # 30秒の時間差を許容
        }
      )
      decoded[0]
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError, JWT::InvalidIssuerError, JWT::InvalidAudError => e
      Rails.logger.error("JWT decode error: #{e.class} - #{e.message}")
      nil
    end
    
    # リフレッシュトークンの生成（ユーザーIDと一意のセッションIDを含む）
    def generate_refresh_token(user_id)
      session_id = SecureRandom.hex(16)
      refresh_exp = Rails.configuration.x.jwt[:refresh_expiration] || 30.days
      
      payload = {
        user_id: user_id,
        session_id: session_id,
        token_type: 'refresh'
      }
      
      token = encode(payload, refresh_exp)
      [token, session_id]
    end
  end
end
