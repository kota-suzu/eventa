class JsonWebToken
  # 秘密鍵を確実に文字列として取得
  SECRET_KEY = Rails.application.credentials.secret_key_base
  # デフォルト有効期限
  TOKEN_EXPIRY = Rails.configuration.x.jwt[:expiration] || 24.hours
  # アルゴリズム
  ALGORITHM = "HS256"
  # アプリケーション識別子（発行者）
  ISSUER = Rails.application.credentials.jwt_issuer || "eventa-api-#{Rails.env}"
  # 想定される受信者（サービス名）
  AUDIENCE = Rails.application.credentials.jwt_audience || "eventa-client"

  class << self
    # JWTトークンのエンコード - expを自動付与
    def encode(payload, exp = TOKEN_EXPIRY)
      payload = payload.dup
      now = Time.current.to_i

      # セキュリティ強化のための標準クレーム
      payload[:iss] = ISSUER            # 発行者
      payload[:aud] = AUDIENCE          # 対象者
      payload[:iat] = now               # 発行時刻
      payload[:nbf] = now               # 有効開始時刻
      payload[:jti] = SecureRandom.uuid # 一意のトークンID

      # expがTimeオブジェクトまたは数値なら適切に処理（修正）
      payload[:exp] = if exp.is_a?(ActiveSupport::Duration)
        exp.from_now.to_i
      elsif exp.is_a?(Time)
        exp.to_i
      elsif exp.is_a?(DateTime)
        exp.to_i
      elsif exp.is_a?(Integer) || exp.is_a?(Float)
        # 整数または浮動小数点の場合はUnixタイムスタンプと解釈してそのまま使用
        exp.to_i
      else
        TOKEN_EXPIRY.from_now.to_i
      end

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # JWTトークンのデコード
    def decode(token)
      raise JWT::DecodeError, "Token cannot be blank" if token.blank?

      # verify_issでiss（発行者）を検証
      # verify_audienceでaud（対象者）を検証
      # verify_iatで発行時刻を検証
      # leeway：検証時の時間ずれを許容する秒数
      JWT.decode(
        token,
        SECRET_KEY,
        true,
        {
          algorithm: ALGORITHM,
          verify_iss: true,
          iss: ISSUER,
          verify_aud: true,
          aud: AUDIENCE,
          verify_iat: true,
          leeway: 30 # 30秒の時間差を許容
        }
      )[0]
    rescue JWT::ExpiredSignature => e
      # トークンの有効期限切れ
      Rails.logger.info "JWT token expired: #{e.message}"
      raise
    rescue JWT::InvalidIssuerError => e
      # 発行者が正しくない
      Rails.logger.info "Invalid JWT issuer: #{e.message}"
      raise
    rescue JWT::InvalidAudError => e
      # 対象者が正しくない
      Rails.logger.info "Invalid JWT audience: #{e.message}"
      raise
    rescue JWT::DecodeError => e
      # その他のデコードエラー
      Rails.logger.info "JWT decode error: #{e.message}"
      raise
    end

    # コントローラーなどの実際の認証処理で使用するメソッド
    # テスト内部ではなく、アプリケーションコードで使用される
    def safe_decode(token)
      # トークンが空やnilの場合は早期リターン
      return nil if token.blank?

      begin
        decode(token)
      rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
        # エラーログを記録
        Rails.logger.info "JWT decode error: #{e.message}"
        nil
      end
    end

    # リフレッシュトークンの生成（ユーザーIDと一意のセッションIDを含む）
    def generate_refresh_token(user_id = nil)
      session_id = SecureRandom.hex(32)

      if user_id.nil?
        return session_id
      end

      refresh_exp = Rails.configuration.x.jwt[:refresh_expiration] || 30.days

      payload = {
        user_id: user_id,
        session_id: session_id,
        token_type: "refresh"
      }

      token = encode(payload, refresh_exp)
      [token, session_id]
    end
  end
end
