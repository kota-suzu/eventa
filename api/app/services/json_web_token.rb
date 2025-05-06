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
      
      # セキュリティクレームを追加
      add_standard_claims(payload)
      
      # 期限を設定
      add_expiry_claim(payload, exp)

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end
    
    # 標準的なセキュリティクレームを追加
    def add_standard_claims(payload)
      now = Time.current.to_i
      payload[:iss] = ISSUER            # 発行者
      payload[:aud] = AUDIENCE          # 対象者
      payload[:iat] = now               # 発行時刻
      payload[:nbf] = now               # 有効開始時刻
      payload[:jti] = SecureRandom.uuid # 一意のトークンID
    end
    
    # 有効期限クレームを追加
    def add_expiry_claim(payload, exp)
      payload[:exp] = calculate_expiry(exp)
    end
    
    # 有効期限を計算
    def calculate_expiry(exp)
      if exp.is_a?(ActiveSupport::Duration)
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
    end

    # JWTトークンのデコード
    def decode(token)
      raise JWT::DecodeError, "Token cannot be blank" if token.blank?

      JWT.decode(
        token,
        SECRET_KEY,
        true,
        decode_options
      )[0]
    rescue JWT::DecodeError => e
      handle_decode_error(e)
    end
    
    # デコードオプションの生成
    def decode_options
      {
        algorithm: ALGORITHM,
        verify_iss: true,
        iss: ISSUER,
        verify_aud: true,
        aud: AUDIENCE,
        verify_iat: true,
        leeway: 30 # 30秒の時間差を許容
      }
    end
    
    # デコードエラーのハンドリング
    def handle_decode_error(error)
      case error
      when JWT::ExpiredSignature
        Rails.logger.info "JWT token expired: #{error.message}"
      when JWT::InvalidIssuerError
        Rails.logger.info "Invalid JWT issuer: #{error.message}"
      when JWT::InvalidAudError
        Rails.logger.info "Invalid JWT audience: #{error.message}"
      else
        Rails.logger.info "JWT decode error: #{error.message}"
      end
      raise error # 呼び出し元で処理できるようにエラーを再度発生させる
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
